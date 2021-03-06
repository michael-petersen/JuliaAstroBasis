"""
Radial basis elements from Clutton-Brock (1973)

@IMPROVE add backup prefactor calculations for alpha,beta

"""

# set the data path for the basis prefactor elements
data_path() = abspath(joinpath(@__DIR__, "tables", "data_CB73_lmax_50_nmax_200.h5"))


"""
    structCB73Basis_type

Radial basis elements from Clutton-Brock (1973)
"""
struct structCB73Basis_type

    name::String         # Basis name (default CB73)
    dimension::Int64     # Basis dimension (default 2)

    lmax::Int64         # Maximal harmonic/azimuthal index (starts at 0)
    nmax::Int64         # Maximal radial index (starts at 0)

    G::Float64       # Gravitational constant (default 1.0)
    rb::Float64      # Radial extension (default 1.0)

    tabPrefU::Array{Float64,2}  # Potential prefactors array
    tabPrefD::Array{Float64,2}  # Density prefactors array

    tabUl::Array{Float64,1}     # Potential elements value array
    tabDl::Array{Float64,1}     # Density elements value array

end


"""
    CB73Basis_create([name, dimension, lmax, nmax, G, rb])

Create a structCB73Basis_type structure

By default,
name="CB73", dimension=2,
lmax=0, nmax=0,
G=1., rb=1.
"""
function CB73Basis_create(;name::String="CB73", dimension::Int64=3,
                            lmax::Int64=0, nmax::Int64=0,
                            G::Float64=1., rb::Float64=1.)

    return structCB73Basis_type(name,dimension,
                                lmax,nmax,
                                G,rb,
                                zeros(Float64,lmax+1,nmax),zeros(Float64,lmax+1,nmax), # Prefactors arrays
                                zeros(Int64,nmax),zeros(Float64,nmax)) # Elements value arrays
end


function fill_prefactors!(basis::structCB73Basis_type,filename::String=data_path())

    tabPrefU,tabPrefD = read_and_fill_prefactors(basis.lmax,basis.nmax,basis.rb,basis.G,filename)

    for l=1:basis.lmax+1
        for n=1:basis.nmax
            basis.tabPrefU[l,n] = tabPrefU[l,n]
            basis.tabPrefD[l,n] = tabPrefD[l,n]
        end
    end

end


"""read_and_fill_prefactors(lmax,nmax[,rb,G,precomputed_filename])

reads a table of pre-computed prefactors for Gegenbauer functions
comes loaded with a pre-computed large table of prefactors (probably more than you need!)

@WARNING: this may only be run once per session, as it will create constants.
"""
function read_and_fill_prefactors(lmax::Int64,nmax::Int64,
                                  rb::Float64=1.,G::Float64=1.,
                                  filename::String=data_path())

    tabalphaCB73 = h5read(filename,"tab_alphalnp") # Reading the prefactors alpha_lnp
    tabbetaCB73  = h5read(filename,"tab_betalnp")  # Reading the prefactors beta_lnp

    #return tabalphaCB73,tabbetaCB73

    # generate blank tables: set up as constants; may only be computed once per session
    tabPrefCB73_Ulnp = zeros(Float64,lmax+1,nmax) # Table of the prefactors of the POTENTIAL basis functions, i.e. the Ulnp !! ATTENTION, size is lmax+1 as l=0 exists
    tabPrefCB73_Dlnp = zeros(Float64,lmax+1,nmax) # Table of the prefactors of the DENSITY   basis functions, i.e. the Dlnp !! ATTENTION, size is lmax+1 as l=0 exists

    for l=0:lmax # Loop over the harmonic indices. ATTENTION, harmonic index starts at l=0
        for n=0:nmax-1 # Loop over the radial basis numbers
            alpha = tabalphaCB73[l+1,n+1]  # Reading the value of alpha. l,np starts at 0
            beta  = tabbetaCB73[l+1,n+1]   # Reading the value of beta.  l,np starts at 0

            A = sqrt(G/rb)*alpha            # Value of the prefactor A_n^\ell
            B = 1.0/(sqrt(G)*rb^(5/2))*beta # Value of the prefactor B_n^\ell

            tabPrefCB73_Ulnp[l+1,n+1] = A  # Filling in the array. l,np starts at 0
            tabPrefCB73_Dlnp[l+1,n+1] = B  # Filling in the array. l,np starts at 0
        end
    end

    return tabPrefCB73_Ulnp,tabPrefCB73_Dlnp

end

"""rhoCB73(x)
Function that returns the parameter -1 <= rho <= 1 for a given dimensionless radius x=r/Rbasis
"""
function rhoCB73(x::Float64)
    return (x^(2) - 1.0)/(x^(2) + 1.0) # Value of rho
end


"""ClnCB73(alpha,n,rho)
Definition of the Gegenbauer polynomials
These coefficients are computed through an upward recurrence
@IMPROVE compute all the basis elements (n)_{1<=n<=nmax} at once
"""
function ClnCB73(alpha::Float64,n::Int64,rho::Float64)

    v0 = 1.0 # Initial value for n=0
    if (n == 0)
        return v0 # No need for a recurrence for n=0
    end

    v1 = 2.0*alpha*rho # Initial value for n=1
    if (n == 1)
        return v1 # No need for a recurrence for n=1
    end

    ic = 2 # Iteration counter that gives the index of the value that is about to be computed
    v = 0.0 # Initialisation of the temporary variable

    while (ic <= n) # Applying the recurrence as many times as needed
        v = (2.0*(ic+alpha-1.0)*rho*v1 - (ic+2.0*alpha-2.0)*v0)/(ic) # Applying the recurrence
        v0, v1 = v1, v # Updating the temporary variables
        ic += 1 # Updating the counter of iteration
    end

    return v # Output of the value
end

"""UlnpCB73(lharmonic,np,r,prefactor_table[,rb])
Definition of the potential radial basis elements from Clutton-Brock (1973)

Be careful: l=0 is index 1, np=0 is index 1.
"""
function UlnpCB73(l::Int64,np::Int64,r::Float64,tabPrefCB73_Ulnp::Matrix{Float64},rb::Float64=1.)
    pref = tabPrefCB73_Ulnp[l+1,np+1]              # Value of the prefactor. l,np start l=0
    x    = r/rb                                    # Dimensionless radius
    rho  = rhoCB73(x)                              # Value of the rescaled parameter rho
    valR = ((x/(1.0+x^(2)))^(l))/(sqrt(1.0+x^(2))) # Value of the multipole factor
    valC = ClnCB73(l+1.0,np,rho)                 # Value of the Gegenbauer polynomials
    res  = pref*valR*valC                          # Value of the radial function
    return res
end

function getUln(basis::structCB73Basis_type,l::Int64,np::Int64,r::Float64)
    return UlnpCB73(l,np,r,basis.tabPrefU,basis.rb)
end


"""DlnpCB73(lharmonic,np,r,prefactor_table[,rb])
Definition of the density radial basis elements from Clutton-Brock (1973)

Be careful: l=0 is index 1, np=0 is index 1.
"""
function DlnpCB73(l::Int64,np::Int64,r::Float64,tabPrefCB73_Dlnp::Matrix{Float64},rb::Float64=1.)
    pref = tabPrefCB73_Dlnp[l+1,np+1]                # Value of the prefactor. ATTENTION, l starts at l = 0
    x    = r/rb                                      # Dimensionless radius
    rho  = rhoCB73(x)                                # Value of the rescaled parameter rho
    valR = ((x/(1.0+x^(2)))^(l))/((1.0+x^(2))^(5/2)) # Value of the multipole factor
    valC = ClnCB73(l+1.0,np,rho)                   # Value of the Gegenbauer polynomials
    res  = pref*valR*valC
    return res
end


function getDln(basis::structCB73Basis_type,l::Int64,np::Int64,r::Float64)
    return DlnpCB73(l,np,r,basis.tabPrefD,basis.rb)
end


"""tabUlnpCB73!(lharmonic,radius,tabUlnp,nmax,prefactor_table[,rb])

Compute CB73 potential table for a given l and r, and for 1 <= np <= nmax, nearly simultaneously

To avoid repeated memory allocations, this overwrites a table already in the struct.

@IMPROVE, create outs for nmax<3?
"""
function tabUlnpCB73!(l::Int64,r::Float64,
                      tabUlnp::Array{Float64,1},
                      nmax::Int64,
                      tabPrefCB73_Ulnp::Matrix{Float64},
                      rb::Float64=1.)

    x     = r/rb                                    # Dimensionless radius
    rho   = rhoCB73(x)                              # Value of the rescaled parameter rho
    valR  = ((x/(1.0+x^(2)))^(l))/(sqrt(1.0+x^(2))) # Value of the multipole factor

    alpha = l+1.0 # Value of alpha, the index of the Gegenbauer polynomials

    # set initial values for recurrence
    v0 = 1.0           # Initial value of the Gegenbauer polynomials for n=0
    tabUlnp[1] = tabPrefCB73_Ulnp[l+1,1]*valR*v0 # Filling in the value for np=1. ATTENTION, l starts at l=0

    v1 = 2.0*alpha*rho # Initial value of the Gegenbauer polynomials for n=1
    tabUlnp[2] = tabPrefCB73_Ulnp[l+1,2]*valR*v1 # Filling in the value for np=2. ATTENTION, l starts at l=0

    for np=2:nmax-1 # Loop over remaining the radial indices
        v = (2.0*(np+alpha-1.0)*rho*v1 - (np+2.0*alpha-2.0)*v0)/(np) # Applying the recurrence
        v0, v1 = v1, v # Updating the temporary variables
        tabUlnp[np+1] = tabPrefCB73_Ulnp[l+1,np+1]*valR*v # Filling in the value for np. ATTENTION, l starts at l=0
    end
end


function tabUl!(basis::structCB73Basis_type,l::Int64,r::Float64)

    tabUlnpCB73!(l,r,basis.tabUl,basis.nmax,basis.tabPrefU,basis.rb)
    #return UlnpCB73(l,np,r,basis.tabPrefU,basis.rb)
end


"""tabDlnpCB73!(lharmonic,radius,tabD,nmax,prefactor_table[,rb])

Compute CB73 density table for a given l and r, and for 1 <= np <= nmax, nearly simultaneously

To avoid repeated memory allocations, this overwrites a table already in the struct.

@IMPROVE, create outs for nmax<3?
"""
function tabDlnpCB73!(l::Int64,r::Float64,
                      tabDlnp::Array{Float64,1},
                      nmax::Int64,
                      tabPrefCB73_Dlnp::Matrix{Float64},
                      rb::Float64=1.)

    x     = r/rb                                      # Dimensionless radius
    rho   = rhoCB73(x)                                # Value of the rescaled parameter rho
    valR  = ((x/(1.0+x^(2)))^(l))/((1.0+x^(2))^(5/2)) # Value of the multipole factor

    alpha = l+1.0 # Value of alpha, the index of the Gegenbauer polynomials

    # set initial values for recurrence
    v0 = 1.0           # Initial value of the Gegenbauer polynomials for n=0
    tabDlnp[1] = tabPrefCB73_Dlnp[l+1,1]*valR*v0 # Filling in the value for np=1. ATTENTION, l starts at l=0

    v1 = 2.0*alpha*rho # Initial value of the Gegenbauer polynomials for n=1
    tabDlnp[2] = tabPrefCB73_Dlnp[l+1,2]*valR*v1 # Filling in the value for np=2. ATTENTION, l starts at l=0

    for np=2:nmax-1 # Loop over remaining the radial indices
        v = (2.0*(np+alpha-1.0)*rho*v1 - (np+2.0*alpha-1.0)*v0)/(np) # Applying the recurrence
        v0, v1 = v1, v # Updating the temporary variables
        tabDlnp[np+1] = tabPrefCB73_Dlnp[l+1,np+1]*valR*v # Filling in the value for np. ATTENTION, l starts at l=0
    end
end


function tabDl!(basis::structCB73Basis_type,l::Int64,r::Float64)

    tabDlnpCB73!(l,r,basis.tabDl,basis.nmax,basis.tabPrefD,basis.rb)
end
