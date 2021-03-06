clear all; close all; clc;

%% Import necessary libs and data

% Add the data to path
addpath("../../data/3DOF/Squat");

% Add model functions
addpath("../Model"); 

% Add the spline functions
addpath("../../libs/splinePack/");  

% Add CASADI library
if ismac                            
    % Code to run on Mac platform
    addpath('../../libs/casadi-osx-matlabR2015a-v3.5.1')
elseif isunix
    % Code to run on Linux platform
    addpath('../../libs/casadi-linux-matlabR2015a-v3.5.1')
elseif ispc
    % Code to run on Windows platform
    addpath('../../libs/casadi-windows-matlabR2016a-v3.5.5')
else
    disp('Platform not supported')
end

% Add generated functions to path and load them in CASADI function form
% from their .mat files
addpath('inverseOptimSquattingComputables\');
load 'nonlinearConstr.mat'
load 'costFunctionSet.mat'

% Load optimal data
load ../../data/3DOF/Optimization-Human/Storage_MinimumTorque_50_ConstraintPoints.mat

% Load squat data
load ../../data/3DOF/Segmentation/SegmentedTrials.mat
%% Define simulation parameters

% Which trial to take
simParam.TrialNumber = 1;

% Number of contraint points
simParam.NumConstraintPoints = 50;

%% Get the cost function and constraint gradient matrices

% Extract parameters of the optimal solution
itpParam = Storage.itpParam;
optParam = Storage.optParam;
modelParam = Storage.modelParam;
x_star = Storage.Results.x_star;

%%
% Extract optimal control points
q1_knot_star = x_star(1:itpParam.NumControlPoints);
q2_knot_star = x_star(1+itpParam.NumControlPoints:2*itpParam.NumControlPoints);
q3_knot_star = x_star(1+2*itpParam.NumControlPoints:3*itpParam.NumControlPoints);

% Get all coefficients from x_star
c1_star = splineInterpolation2(itpParam.KnotValues, q1_knot_star, itpParam.InterpolationOrder, itpParam.BoundaryConditions);
c2_star = splineInterpolation2(itpParam.KnotValues, q2_knot_star, itpParam.InterpolationOrder, itpParam.BoundaryConditions);
c3_star = splineInterpolation2(itpParam.KnotValues, q3_knot_star, itpParam.InterpolationOrder, itpParam.BoundaryConditions);

% Store spline interpolation parameters
oldKnotValues = itpParam.KnotValues;

% Modify all parameters to correspond to desired inverse model
parameter_def_itp_model_opt_inverse;

% Get all trajectories from coefficients
q1_star = splineCoefToTrajectory(oldKnotValues, c1_star, itpParam.KnotValues, 0);
q2_star = splineCoefToTrajectory(oldKnotValues, c2_star, itpParam.KnotValues, 0);
q3_star = splineCoefToTrajectory(oldKnotValues, c3_star, itpParam.KnotValues, 0);

% Stack into a single vector to make the new optimal vector
x_star = [q1_star, q2_star, q3_star];

%%

% Get the cost function and its gradient
[J_star, dJ_star] = fullify(@(x)costFunctionSet(x), x_star);

% Get the nonlinear constraint functions and its gradients
[C_star, Ceq_star, dC_star, dCeq_star] = fullify(@(x)nonlinearConstr(x), x_star);

% Get the linear constraint matrices
[A_star, b_star, Aeq_star, beq_tar] = inverseOptimGenerateLinearConstraintMatricesSquatting3DOF(itpParam, optParam, modelParam);

%% Preprocess gradient matrices to prepare them for IOC

% Reshape all gradient matrices such that their number of rows equals the
% number of rows of the optimization variable
% Gradient of cost function
if size(dJ_star, 1) ~= length(x_star)
    dJ_star = dJ_star';
end
% Gradient of nonlinear inequality constraints
if size(dC_star, 1) ~= length(x_star)
    dC_star = dC_star';
end
% Gradient of nonlinear equality constraints
if size(dCeq_star, 1) ~= length(x_star)
    dCeq_star = dCeq_star';
end
% Gradient of linear inequality constraints
if size(A_star, 1) ~= length(x_star)
    A_star = A_star';
end
% Gradient of linear equality constraints
if size(Aeq_star, 1) ~= length(x_star)
    Aeq_star = Aeq_star';
end

% Append nonlinear and linear inequality gradients into a single matrix
dIneq = [A_star, dC_star];

% Append nonlinear and linear equality gradients into a single matrix
dEq = [Aeq_star, dCeq_star];

% Append nonlinear and linear inequality values into a single vector but
% first reshape them into row vectors
rshpIneqLin = reshape(x_star * reshape(A_star, length(x_star), []) - reshape(b_star, 1, []), 1, []);
Ineq = [rshpIneqLin, reshape(C_star, 1, [])];

% Keep only inequality constraints and gradients of inequality constraints
% which are active
dIneq = dIneq(:, Ineq >= 0);
Ineq = Ineq(Ineq >= 0);

% Get the different constants of interest

% Number of optimization variables
n = length(x_star);
% Number of cost functions
Ncf = size(dJ_star, 2);
% Number of equality constraints
m = size(dEq, 2);
% Number of inequality constraints
p = size(dIneq, 2);

%% Formulate the IOC problem as a constraint least-squares problem
% Notation from the MATLAB lsqlin documentation will be adopted

% Get Stationarity matrix
M_stat = [dJ_star, dEq, dIneq];

% Get Complementarity matrix
M_compl = [zeros(p, Ncf), zeros(p, m), diag(Ineq)];

% Get Multiplicative matrix
C = [M_stat; M_compl];

% Get Yielding Matrix
d = zeros(n+p, 1);

% There are no inequalities (there are bounds)
A = [];
b = [];

% Only equality is that the sum of cost function parameters must be 1
Aeq = zeros(1, Ncf+m+p);
Aeq(1, 1:Ncf) = 1;
beq = 1;

% Lower bounds exist on cost function parameters and inequality langrange
% multiplicators and are equal to zero (an arbitrary lower bound of lb_lam
% shall be placed upon equality lagrange multipliers to limit the search
% space)
lb_lam = -1e3; 
lb = [zeros(Ncf, 1); -1e3 * ones(m, 1); zeros(p, 1)];
ub = [];

%% Inverse optimization pipeline

% Get optimal coefficients
[vars_ioc,rn_ioc,res_ioc,ef_ioc,out_ioc,~] = lsqlin(C,d,A,b,Aeq,beq,lb,ub);

% Extract difference quantities
alpha_ioc = vars_ioc(1:Ncf);
lambda_ioc = vars_ioc(Ncf+1 : Ncf+m);
mu_ioc = vars_ioc(Ncf+m+1 : Ncf+m+p);

%% Investigate the residual norm the residual itself

figure;

subplot(1, 3, [1 2])
% Plot residual accross dimension
barValues = res_ioc;
numbars = length(res_ioc);
barLocations = 1:numbars;
barNames = {};
for ii = 1 : numbars
    barNames{ii} = ['Dim. ' num2str(ii, '%02d')];
end
hold on;
barChart = bar(barLocations, barValues);
barChart.FaceColor = 'flat';    % Let the facecolors be controlled by CData
barChart.CData = repmat(linspace(0.2, 0.8, numbars)', 1, 3);     % Set CData
xticks(barLocations(1:10:end));
xticklabels(barNames(1:10:end));
xtickangle(70);
ylabel('Residual of the Lagrangian along given dimension');
title({'Investigating the ';'residual of the Lagrangian'});

subplot(1, 3, 3)
% Plot a single bar that represents the residual norm
barValues = rn_ioc;
numbars = length(rn_ioc);
barLocations = 1:numbars;
barNames = {'Residual Norm'};
hold on;
barChart = bar(barLocations, barValues);
barChart.FaceColor = 'flat';    % Let the facecolors be controlled by CData
barChart.CData = repmat(linspace(0.2, 0.8, numbars)', 1, 3);     % Set CData
xticks(barLocations);
xticklabels(barNames);
xtickangle(0);
ylabel('Residual norm of the Lagrangian');
title({'Investigating the residual';' norm of the Lagrangian'});

%% Compare found cost function coefficient values to stored coefficient values

figure;
% Plot a bars that represent the cost implication
barValues = [optParam.CostFunctionWeights; alpha_ioc'];
numbars = length(alpha_ioc);
barLocations = 1:numbars;
barNames = {};
for ii = 1 : numbars
    barNames{ii} = ['\alpha_{' num2str(ii) '}'];
end
hold on;
barChart = bar(barLocations, barValues);
set(barChart, {'DisplayName'}, {'Original'; 'Retrieved'})
xticks(barLocations);
xticklabels(barNames);
xtickangle(0);
ylabel('Values of cost function parametrization');
title({'Investigating the';'cost function parametrization'});
legend;

%% Check if columns of the matrices are linearly independents

% Check for J_star
[dJ_star_sub, ind_dJ_star] = licols(dJ_star, 1e-3);
% size(ind_dJ_star)
% Check for matrix C
[C_sub, ind_C] = licols(C, 1e-3);
% size(ind_C)
% Print the residual norm
fprintf("The residual norm of inverse optimization is %.4f.\n", rn_ioc);
% Check rank of C
fprintf("The size of the recovery matrix is [%d, %d] while its rank is %d.\n", size(C), rank(C));
fprintf("The condition number of the recovery matrix is %.4f.\n", cond(C));
% Check rank of part of C corresponding to the part of the recovery matrix
% that is relative to the cost functions
fprintf("The size of the cost function part of the recovery matrix is [%d, %d] while its rank is %d.\n", size(C(:, 1:Ncf)), rank(C(:, 1:Ncf)));
fprintf("The condition number of the cost function part of the recovery matrix is %.4f.\n", cond(C(:, 1:Ncf)));