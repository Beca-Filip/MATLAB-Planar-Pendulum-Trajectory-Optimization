%% Display Initial Solution vs. Joint Limits

two1 = ones(1, 2);
figure;

subplot(3, 1, 1)
hold on;
stem(itpParam.KnotValues, q1_knot_0, 'DisplayName', 'InitialPoints q_1');
plot(itpParam.KnotValues([1, end]), modelParam.JointLimits(1, 1)*two1, 'DisplayName', 'Lower bound');
plot(itpParam.KnotValues([1, end]), modelParam.JointLimits(2, 1)*two1, 'DisplayName', 'Upper bound');
legend('Location','Best');
xlabel('time [s]');
ylabel('joint angle [rad]');
title({'1^{st} third of Optimization Variables'; 'Joint 1 Control Points'});

subplot(3, 1, 2)
hold on;
stem(itpParam.KnotValues, q2_knot_0, 'DisplayName', 'InitialPoints q_2');
plot(itpParam.KnotValues([1, end]), modelParam.JointLimits(1, 2)*two1, 'DisplayName', 'Lower bound');
plot(itpParam.KnotValues([1, end]), modelParam.JointLimits(2, 2)*two1, 'DisplayName', 'Upper bound');
legend('Location','Best');
xlabel('time [s]');
ylabel('joint angle [rad]');
title({'2^{nd} third of Optimization Variables'; 'Joint 2 Control Points'});

subplot(3, 1, 3)
hold on;
stem(itpParam.KnotValues, q3_knot_0, 'DisplayName', 'InitialPoints q_3');
plot(itpParam.KnotValues([1, end]), modelParam.JointLimits(1, 3)*two1, 'DisplayName', 'Lower bound');
plot(itpParam.KnotValues([1, end]), modelParam.JointLimits(2, 3)*two1, 'DisplayName', 'Upper bound');
legend('Location','Best');
xlabel('time [s]');
ylabel('joint angle [rad]');
title({'3^{rd} third of Optimization Variables'; 'Joint 3 Control Points'});


%% Calculate initial and final position neck and hip height

% Use FKM to determine cartesian positions of joints
T0 = FKM_3DOF_Tensor(q0, L);
Tf = FKM_3DOF_Tensor(qf, L);

% Get hip heights
hh0 = T0(2, 4, end-1);
hhf = Tf(2, 4, end-1);

% Get neck heights
nh0 = T0(2, 4, end);
nhf = Tf(2, 4, end);

fprintf("The inital and final hip height are hh0 = %.4fm and hhf = %.4fm .\n", hh0, hhf);
fprintf("Their ration is hhf / hh0 = %.4f .\n", hhf / hh0);
fprintf("The inital and final neck height are nh0 = %.4fm and nhf = %.4fm .\n", nh0, nhf);
fprintf("Their ration is nhf / nh0 = %.4f .\n", nhf / nh0);

%% Calculate Initial Trajectories and Compare with Optimal Trajectories
% Get spline interpolation coefs for each joint trajectory
polycoefs1_0 = splineInterpolation(itpParam.KnotValues, q1_knot_0, p, bndcnd);
polycoefs2_0 = splineInterpolation(itpParam.KnotValues, q2_knot_0, p, bndcnd);
polycoefs3_0 = splineInterpolation(itpParam.KnotValues, q3_knot_0, p, bndcnd);

% Get spline trajectories from coeffs
q1_0 = splineCoefToTrajectory(itpParam.KnotValues, polycoefs1_0, t, 2);
q2_0 = splineCoefToTrajectory(itpParam.KnotValues, polycoefs2_0, t, 2);
q3_0 = splineCoefToTrajectory(itpParam.KnotValues, polycoefs3_0, t, 2);

% Pack trajectories into a single matrix
ddq_0 = [q1_0(3, :); q2_0(3, :); q3_0(3, :)];
dq_0 = [q1_0(2, :); q2_0(2, :); q3_0(2, :)];
q_0 = [q1_0(1, :); q2_0(1, :); q3_0(1, :)];

% Plot them
two1 = ones(1, 2);  % Helper
figure;

subplot(3, 1, 1)
hold on;
plot(t, q_0(1, :), 'b--', 'DisplayName', 'Initial Traj');
plot(t, q_star(1, :), 'LineWidth', 2, 'DisplayName', 'Optimal Traj');
plot(t([1 end]), modelParam.JointLimits(1, 1)*two1, 'k--', 'DisplayName', 'Lower bound');
plot(t([1 end]), modelParam.JointLimits(2, 1)*two1, 'k--', 'DisplayName', 'Upper bound');
legend('Location','Best');
xlabel('time [s]');
ylabel('joint angle [rad]');
title({'Comparison of 1^{st} joint trajectories'});
grid;

subplot(3, 1, 2)
hold on;
plot(t, q_0(2, :), 'b--', 'DisplayName', 'Initial Traj');
plot(t, q_star(2, :), 'LineWidth', 2, 'DisplayName', 'Optimal Traj');
plot(t([1 end]), modelParam.JointLimits(1, 2)*two1, 'k--', 'DisplayName', 'Lower bound');
plot(t([1 end]), modelParam.JointLimits(2, 2)*two1, 'k--', 'DisplayName', 'Upper bound');
legend('Location','Best');
xlabel('time [s]');
ylabel('joint angle [rad]');
title({'Comparison of 2^{nd} joint trajectories'});
grid;

subplot(3, 1, 3)
hold on;
plot(t, q_0(3, :), 'b--', 'DisplayName', 'Initial Traj');
plot(t, q_star(3, :), 'LineWidth', 2, 'DisplayName', 'Optimal Traj');
plot(t([1 end]), modelParam.JointLimits(1, 3)*two1, 'k--', 'DisplayName', 'Lower bound');
plot(t([1 end]), modelParam.JointLimits(2, 3)*two1, 'k--', 'DisplayName', 'Upper bound');
legend('Location','Best');
xlabel('time [s]');
ylabel('joint angle [rad]');
title({'Comparison of 3^{rd} joint trajectories'});
grid;

%% Calculate Torques for Initial Trajectories and Compare with Optimal Trajectories

% Flags
plotTorqueLimits = false;

% Get the zero external wrenches object
ZEW = zeroExternalWrenches3DOF(size(q_star, 2));

% Calculate the dynamics for optimal trajectory
[GAMMA_star, ~] = Dyn_3DOF(q_star, dq_star, ddq_star, ZEW, modelParam);

% Calculate the dynamics for initial trajectory
[GAMMA_0, ~] = Dyn_3DOF(q_0, dq_0, ddq_0, ZEW, modelParam);

% Compare graphically
figure;

subplot(3, 1, 1)
hold on;
plot(t, GAMMA_0(1, :), 'b--', 'DisplayName', 'Torques of Initial Traj');
plot(t, GAMMA_star(1, :), 'LineWidth', 2, 'DisplayName', 'Torques of Optimal Traj');
if plotTorqueLimits
    plot(t([1 end]), -modelParam.TorqueLimits(1, 1)*two1, 'k--', 'DisplayName', 'Lower bound');
    plot(t([1 end]), modelParam.TorqueLimits(1, 1)*two1, 'k--', 'DisplayName', 'Upper bound');
end
legend('Location','Best');
xlabel('time [s]');
ylabel('joint torque [Nm]');
title({'Comparison of 1^{st} joint torques'});
grid;

subplot(3, 1, 2)
hold on;
plot(t, GAMMA_0(2, :), 'b--', 'DisplayName', 'Torques of Initial Traj');
plot(t, GAMMA_star(2, :), 'LineWidth', 2, 'DisplayName', 'Torques of Optimal Traj');
if plotTorqueLimits
    plot(t([1 end]), -modelParam.TorqueLimits(1, 2)*two1, 'k--', 'DisplayName', 'Lower bound');
    plot(t([1 end]), modelParam.TorqueLimits(1, 2)*two1, 'k--', 'DisplayName', 'Upper bound');
end
legend('Location','Best');
xlabel('time [s]');
ylabel('joint torque [Nm]');
title({'Comparison of 2^{nd} joint torques'});
grid;

subplot(3, 1, 3)
hold on;
plot(t, GAMMA_0(3, :), 'b--', 'DisplayName', 'Torques of Initial Traj');
plot(t, GAMMA_star(3, :), 'LineWidth', 2, 'DisplayName', 'Torques of Optimal Traj');
if plotTorqueLimits
    plot(t([1 end]), -modelParam.TorqueLimits(1, 3)*two1, 'k--', 'DisplayName', 'Lower bound');
    plot(t([1 end]), modelParam.TorqueLimits(1, 3)*two1, 'k--', 'DisplayName', 'Upper bound');
end
legend('Location','Best');
xlabel('time [s]');
ylabel('joint torque [Nm]');
title({'Comparison of 3^{rd} joint torques'});
grid;

%% Compare Square of Normalized Joint Torques Between Initial and Optimal Solution

% Flags
plotSquaredTorqueLimits = true;

% Squared normalized torque limits
squaredTorqueLimits = modelParam.TorqueLimits.^2;

% Calculate sum of squares of normalized torque of initial trajectory
J_0 = sum(GAMMA_0.^2 ./ (modelParam.TorqueLimits.^2)') / 3 / size(q_0, 2);

% Calculate sum of squares of normalized torque of optimal trajectory
J_star = sum(GAMMA_star.^2 ./ (modelParam.TorqueLimits.^2)') / 3 / size(q_star, 2);

% Compare graphically
figure;

hold on;
plot(t, J_0(1, :), 'b--', 'DisplayName', 'Torques of Initial Traj');
plot(t, J_star(1, :), 'LineWidth', 2, 'DisplayName', 'Torques of Optimal Traj');
if plotSquaredTorqueLimits
%     plot(t([1 end]), -modelParam.TorqueLimits(1, 1)*two1, 'k--', 'DisplayName', 'Lower bound');
end
legend('Location','Best');
xlabel('time [s]');
ylabel('joint torque [Nm]');
title({'Comparison of 1^{st} joint torques'});
grid;