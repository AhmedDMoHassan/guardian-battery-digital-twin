close all
clc
clearvars
%% Current and time

driveCycleTbl = readtable('Guardian_Battery_DriveCycle_Current (1)');
ocvLookupTbl  = readtable('Guardian_Battery_OCV_SOC_Table (1)');

t_vec_s   = driveCycleTbl.Time_s;
I_drive_A = driveCycleTbl.Current_A;

SOC_breakpoints = ocvLookupTbl.SOC_pct;
OCV_data = ocvLookupTbl.OCV_V;

I_workspace = [t_vec_s , I_drive_A];

T_end_s = max(t_vec_s);

%% Constants

Ts = 0.1;
Q_nominal = 50; % Ah
R0_ref = 0.0007; % ohm
R1_ref = 0.0016; % ohm
C1_ref = 17000; % F
R2_ref = 0.00035; % ohm
C2_ref = 5200; % F
tau1_s = R1_ref * C1_ref;
tau2_s = R2_ref * C2_ref;
a1_coef = exp(-Ts/(tau1_s));
a2_coef = exp(-Ts/(tau2_s));
SOC_init_pct = 80;

%% Hysteresis Noise Filter (FR-3, rescaled for Ts)
% FR-3 specifies this filter at Ts_ref = 1 s: Numerator = [0.02],
% Denominator = [1 -0.98] (tau ~= 49.5 s, unity DC gain). Rescaled here
% to preserve that same physical bandwidth at the model's actual Ts_sim --
% left as Ts=1 while everything else moves to 0.1 would make the
% hysteresis noise ~10x jitterier than the reference realization.
% Noise Power (1e-4) and Saturation limits (+-0.005) are Ts-independent
% and stay as FR-3 specifies them.

Ts_hyst_ref     = 1;
a_hyst_baseline = 0.98;
a_hyst_coef     = a_hyst_baseline ^ (Ts / Ts_hyst_ref);
hyst_filt_num   = 1 - a_hyst_coef;
hyst_filt_den   = [1, -a_hyst_coef];

% Apply in Simulink:
%   Band-Limited White Noise block -> Sample time = Ts_sim
%   Discrete Filter block          -> Numerator = hyst_filt_num,
%                                      Denominator = hyst_filt_den

%% Bus

busElems(1) = Simulink.BusElement;
busElems(1).Name = 'SOC_CC'; busElems(1).DataType = 'double';

busElems(2) = Simulink.BusElement;
busElems(2).Name = 'SOC_Flag'; busElems(2).DataType = 'boolean';

busElems(3) = Simulink.BusElement;
busElems(3).Name = 'SOC_hat'; busElems(3).DataType = 'double';

busElems(4) = Simulink.BusElement;
busElems(4).Name = 'V1_hat'; busElems(4).DataType = 'double';

busElems(5) = Simulink.BusElement;
busElems(5).Name = 'V2_hat'; busElems(5).DataType = 'double';

busElems(6) = Simulink.BusElement;
busElems(6).Name = 'R0_TLS'; busElems(6).DataType = 'double';

busElems(7) = Simulink.BusElement;
busElems(7).Name = 'SOH_ratio'; busElems(7).DataType = 'double';

busElems(8) = Simulink.BusElement;
busElems(8).Name = 'V_terminal'; busElems(8).DataType = 'double';

GuardianCellBus = Simulink.Bus;
GuardianCellBus.Elements = busElems;
% GuardianCellBus is the INNER Cell_data bus (Cell_DigitalTwin's own
% wiring) -- 8 elements including internal-only diagnostics (SOC_CC,
% V1_hat, V2_hat). It is NOT the right bus object for the outer
% Battery_data port -- see BatteryDataBus below for that boundary.

%% Bus (public -- Battery_data outport)
% Narrower, 5-element interface matching what's actually wired into the
% Battery_data outport -- the boundary this referenced model exposes to
% whatever calls it, so it deliberately excludes internal-only signals
% (SOC_CC, V1_hat, V2_hat) that GuardianCellBus carries for wiring
% inside DigitalTwin_and_SOC_SOH.

busElemsPublic(1) = Simulink.BusElement;
busElemsPublic(1).Name = 'R0_TLS'; busElemsPublic(1).DataType = 'double';

busElemsPublic(2) = Simulink.BusElement;
busElemsPublic(2).Name = 'SOH_ratio'; busElemsPublic(2).DataType = 'double';

busElemsPublic(3) = Simulink.BusElement;
busElemsPublic(3).Name = 'SOC_EKF'; busElemsPublic(3).DataType = 'double';

busElemsPublic(4) = Simulink.BusElement;
busElemsPublic(4).Name = 'SOC_Flag'; busElemsPublic(4).DataType = 'boolean';

busElemsPublic(5) = Simulink.BusElement;
busElemsPublic(5).Name = 'V_terminal'; busElemsPublic(5).DataType = 'double';

BatteryDataBus = Simulink.Bus;
BatteryDataBus.Elements = busElemsPublic;

%% Plots

% subplot( 4 , 4 , [1 5 9 13])
% plot(t_vec_s , out.OCV_used.signals.values , Color = "b")
% xlabel('Time (s)')
% ylabel('OCV USED (V)')
% grid on
%
% subplot( 4 , 4 , [2 6 10 14])
% plot(t_vec_s , out.V1.signals.values , Color = "g")
% xlabel('Time (s)')
% ylabel('V1 (V)')
% grid on
%
% subplot( 4 , 4 , [3 7 11 15])
% plot(t_vec_s , out.SOC_CC.signals.values , Color = "r")
% xlabel('Time (s)')
% ylabel('SOC CC (%)')
% grid on
%
% subplot( 4 , 4 , [4 8 12 16])
% plot(t_vec_s , out.Terminal_Voltage.signals.values , Color = "c")
% xlabel('Time (s)')
% ylabel('Voltage TERMINAL (V)')
% grid on