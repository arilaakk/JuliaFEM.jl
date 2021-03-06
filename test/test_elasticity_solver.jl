# This file is a part of JuliaFEM.
# License is MIT: see https://github.com/JuliaFEM/JuliaFEM.jl/blob/master/LICENSE.md

using FactCheck
using Logging
@Logging.configure(level=INFO)


using JuliaFEM.elasticity_solver: solve_elasticity_increment!

function one_elem_fixture()
  X = [0.0 0.0; 10.0 0.0; 10.0 1.0; 0.0 1.0]'
  elmap = [1; 2; 3; 4]
  nodalloads = [0 0; 0 0; 0 -2; 0 0]'
  @debug("nodal loads:\n", nodalloads)
  dirichletbc = [0 0; NaN NaN; NaN NaN; 0 0]'

  E = 90
  nu = 0.25
  mu = E/(2*(1+nu))
  la = E*nu/((1+nu)*(1-2*nu))
  la = 2*la*mu/(la + 2*mu)

  la = la*ones(1, 4)
  mu = mu*ones(1, 4)
  u = zeros(2, 4)
  du = zeros(2, 4)

  N(xi) = [
      (1-xi[1])*(1-xi[2])/4
      (1+xi[1])*(1-xi[2])/4
      (1+xi[1])*(1+xi[2])/4
      (1-xi[1])*(1+xi[2])/4
    ]

  dNdξ(ξ) = [-(1-ξ[2])/4.0    -(1-ξ[1])/4.0
              (1-ξ[2])/4.0    -(1+ξ[1])/4.0
              (1+ξ[2])/4.0     (1+ξ[1])/4.0
             -(1+ξ[2])/4.0     (1-ξ[1])/4.0]

  ipoints = 1/sqrt(3)*[-1 -1; 1 -1; 1 1; -1 1]
  iweights = [1 1 1 1]

    return (X, u, du, elmap, nodalloads, dirichletbc,
     la, mu, N, dNdξ, ipoints, iweights)
end

facts("test solve elasticity increment") do

    (X, u, du, elmap, nodalloads, dirichletbc,
     la, mu, N, dNdξ, ipoints, iweights) = one_elem_fixture()

  for i=1:10
    solve_elasticity_increment!(X, u, du, elmap, nodalloads, dirichletbc,
                                la, mu, N, dNdξ, ipoints, iweights)
    @debug("increment:\n",du)
    u += du
    if norm(du) < 1.0e-9
      break
    end
  end
  @debug("solution\n",u)
  @fact u[2, 3] => roughly(-2.222244754401764)  # Tested against Elmer solution
end


facts("test solve elasticity increment rot 30") do

    (X, u, du, elmap, nodalloads, dirichletbc,
     la, mu, N, dNdξ, ipoints, iweights) = one_elem_fixture()

    phi = 30/180*pi
    rmat = [cos(phi) -sin(phi); sin(phi) cos(phi)]
    X = rmat*X
    nodalloads = rmat*nodalloads

  for i=1:10
    solve_elasticity_increment!(X, u, du, elmap, nodalloads, dirichletbc,
                                la, mu, N, dNdξ, ipoints, iweights)
    @debug("increment:\n",du)
    u += du
    if norm(du) < 1.0e-9
      break
    end
  end
    u = rmat'*u
  @debug("solution\n",u)
  @fact u[2, 3] => roughly(-2.222244754401764)  # Tested against Elmer solution
end


facts("test solve elasticity increment, two elements") do

    X = Float64[0 0; 1 0; 2 0; 0 1; 1 1; 2 1]'
  elmap = [1 2 5 4; 2 3 6 5]'
  nodalloads = [0 0; 0 0; 0 0; 0 0; 0 0; -3 0]'
  @debug("nodal loads:\n", nodalloads)
  dirichletbc = [0 0; NaN NaN; NaN NaN; 0 0; NaN NaN; NaN NaN]'

    dim, nnodes = size(X)

  E = 90
  nu = 0.25
  mu = E/(2*(1+nu))
  la = E*nu/((1+nu)*(1-2*nu))
  la = 2*la*mu/(la + 2*mu)

    la = la*ones(1, nnodes)
    mu = mu*ones(1, nnodes)
    u = zeros(dim, nnodes)
    du = zeros(dim, nnodes)

  N(xi) = [
      (1-xi[1])*(1-xi[2])/4
      (1+xi[1])*(1-xi[2])/4
      (1+xi[1])*(1+xi[2])/4
      (1-xi[1])*(1+xi[2])/4
    ]

  dNdξ(ξ) = [-(1-ξ[2])/4.0    -(1-ξ[1])/4.0
              (1-ξ[2])/4.0    -(1+ξ[1])/4.0
              (1+ξ[2])/4.0     (1+ξ[1])/4.0
             -(1+ξ[2])/4.0     (1-ξ[1])/4.0]

  ipoints = 1/sqrt(3)*[-1 -1; 1 -1; 1 1; -1 1]
  iweights = [1 1 1 1]

  for i=1:10
    solve_elasticity_increment!(X, u, du, elmap, nodalloads, dirichletbc,
                                la, mu, N, dNdξ, ipoints, iweights)
    @debug("increment:\n",du)
    u += du
    if norm(du) < 1.0e-9
      break
    end
  end
    @debug("solution\n",u)
    # Known to fail, test against elmer.
  @pending u[2, 6] => roughly(:something)
end


using JuliaFEM.elasticity_solver: interpolate
facts("test interpolation of different field variables") do
    N(xi) = [
      (1-xi[1])*(1-xi[2])/4
      (1+xi[1])*(1-xi[2])/4
      (1+xi[1])*(1+xi[2])/4
      (1-xi[1])*(1+xi[2])/4
    ]
    dNdξ(ξ) = [-(1-ξ[2])/4.0    -(1-ξ[1])/4.0
                (1-ξ[2])/4.0    -(1+ξ[1])/4.0
                (1+ξ[2])/4.0     (1+ξ[1])/4.0
               -(1+ξ[2])/4.0     (1-ξ[1])/4.0]
    F1 = [36.0, 36.0, 36.0, 36.0]
    F2 = [36.0 36.0 36.0 36.0]
    F3 = F2'
    F4 = [0.0 0.0; 10.0 0.0; 10.0 1.0; 0.0 1.0]'
    F5 = F4'
    F6 = [36, 36, 36, 36]

    @fact interpolate(F1, N, [0.0, 0.0]) => 36.0
    @fact interpolate(F2, N, [0.0, 0.0]) => 36.0
    @fact interpolate(F3, N, [0.0, 0.0]) => 36.0
    @fact interpolate(F4, N, [0.0, 0.0]) => [5.0; 0.5]
    @fact interpolate(F5, N, [0.0, 0.0]) => [5.0; 0.5]
    @fact interpolate(F5, dNdξ, [0.0, 0.0]) => [5.0 0.0; 0.0 0.5]
    @fact interpolate(F6, N, [0.0, 0.0]) => 36
end



using JuliaFEM.elasticity_solver: assemble!

facts("test assembly of global matrix for 1 dim/node case") do
    I = Int64[]
    J = Int64[]
    V = Float64[]
    ke = [3 1; 1 1]
    eldofs = [1, 2]
    assemble!(ke, eldofs, I, J, V)
    ke = [4 2; 2 3]
    eldofs = [2, 4]
    assemble!(ke, eldofs, I, J, V)
    S = full(sparse(I, J, V))
    @fact S => [3.0 1.0 0.0 0.0
                1.0 5.0 0.0 2.0
                0.0 0.0 0.0 0.0
                0.0 2.0 0.0 3.0]
end

facts("test assembly of global vector for 1 dim/node case") do
    I = Int64[]
    V = Float64[]
    fe = [1;2]
    eldofs = [1, 2]
    assemble!(fe, eldofs, I, V)
    fe = [3;1]
    eldofs = [2, 4]
    assemble!(fe, eldofs, I, V)
    S = full(sparsevec(I, V))
    @fact S => [1.0 5.0 0.0 1.0]'
end

facts("test assembly of global matrix for 2 dim/node case") do
    # provide "convienence" function, if given only nodal connectivity
    # automatically find out dimension and "extend" matrix to full
    I = Int64[]
    J = Int64[]
    V = Float64[]
    ke = reshape(1:16, 4, 4)
    eldofs = [1, 2]
    assemble!(ke, eldofs, I, J, V)
    eldofs = [2, 3]
    assemble!(2*ke, eldofs, I, J, V)
    expected = zeros(6, 6)
    expected[1:4,1:4] += ke
    expected[3:6,3:6] += 2*ke
    S = full(sparse(I, J, V))
    @fact S => expected
end

facts("test assembly of global vector for 2 dim/node case") do
    # provide "convienence" function, if given only nodal connectivity
    # automatically find out dimension and "extend" matrix to full
    I = Int64[]
    J = Int64[]
    V = Float64[]
    fe = [1, 2, 3, 4]
    eldofs = [1, 2]
    assemble!(fe, eldofs, I, V)
    eldofs = [2, 3]
    assemble!(2*fe, eldofs, I, V)
    S = full(sparsevec(I, V))
    expected = [1.0 2.0 5.0 8.0 6.0 8.0]'
    @fact S => expected
end


using JuliaFEM.elasticity_solver: eliminate_boundary_conditions
facts("remove boundary conditions from matrix with 2 dof/node") do
    # create sparse matrix 4x4 with some data
    # 4x4 Array{Int64,2}:
    #  1  5   9  13
    #  2  6  10  14
    #  3  7  11  15
    #  4  8  12  16
    A = sparse(reshape(1:4*4, 4, 4))
    I, J, V = findnz(A)
    # we plan to eliminate first dof of first node and second dof of second node
    # expected output would be
    # 6 10
    # 7 11
    dirichletbc = [0 NaN; NaN 0]'
    I, J, V = eliminate_boundary_conditions(dirichletbc, I, J, V)
    A2 = full(sparse(I, J, V))
    @fact A2 => [6 10; 7 11]
end

facts("remove boundary conditions from vector with 2 dof/node") do
    # create sparse vector dim 4 with some data
    #  1 2 3 4 '
    A = sparsevec([1, 2, 3, 4])
    I, J, V = findnz(A)
    # we plan to eliminate first dof of first node and second dof of second node
    # expected output would be
    # 2 3
    dirichletbc = [0 NaN; NaN 0]'
    I, V = eliminate_boundary_conditions(dirichletbc, I, V)
    A2 = full(sparsevec(I, V))
    @fact A2 => [2 3]'
end

facts("test that elimination of non-homogeneous dirichlet boundary conditions raises error because they are not supported atm") do
    A = sparse(reshape(1:4*4, 4, 4))
    I, J, V = findnz(A)
    dirichletbc = [0 1; NaN 0]'
    @fact_throws I, J, V = eliminate_boundary_conditions(dirichletbc, I, J, V)
    A = sparsevec([1, 2, 3, 4])
    I, J, V = findnz(A)
    @fact_throws I, V = eliminate_boundary_conditions(dirichletbc, I, V)
end
