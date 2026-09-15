# Guardian Battery ECM — Cell Digital Twin & SOC/SOH Estimation

A discrete-time digital twin of a single LiFePO4 cell: a 2RC Thevenin equivalent-circuit model driven by Coulomb Counting, a 2RC/3-state Extended Kalman Filter, and a recursive Total Least Squares identifier for online internal-resistance (R0) and State-of-Health tracking — built as a genuine closed-loop **joint state/parameter estimation** architecture, not three independent bonus features bolted together.

Reference cell: **EVE LF50K, 3.2 V / 50 Ah LiFePO4** (prismatic).

## Highlights

- **2RC Thevenin ECM** — exact zero-order-hold discretization of the RC branches, valid at any sample time.
- **Coulomb Counting SOC** — the core, always-available SOC estimate.
- **EKF SOC estimator** — 3-state (SOC, V1, V2), with R0 promoted from a fixed constant to a **live, TLS-fed input** rather than a hardcoded datasheet value.
- **Recursive TLS R0/SOH identifier** — online, continuously-updating (not a single end-of-run batch fit), closing the loop back into the EKF through a one-sample delay.
- **Two interchangeable TLS variants**, selectable via a **Variant Subsystem**:
  - *Coupled* — sources polarization voltage from the EKF's own estimates.
  - *Open-loop* — computes an independent polarization replica from the known R1/C1/R2/C2, matching the original course spec's design intent.
- Runs at **Ts = 0.1 s** (rescaled from an original Ts = 1 s baseline — every Ts-dependent coefficient, from the hysteresis noise filter to the TLS forgetting factor, is derived analytically from Ts, not hardcoded).

## Repository structure

```
Guardian_Battery/
├── Guardian_Battery.slx                  # top-level model
├── Guardian_Battery_script.m             # base-workspace setup — run first
├── EKF_SOC_Estimator.m                   # 2RC/3-state EKF, live R0 input
├── TLS_RO_SOH_block.m                    # recursive TLS — Coupled variant
├── TLS_RO_SOH_block_openloop.m           # recursive TLS — Open-loop variant
├── Guardian_Battery_DriveCycle_Current.csv
├── Guardian_Battery_OCV_SOC_Table.csv
├── Guardian_Battery_ECM_Documentation.docx  # full write-up (architecture, equations, results)
└── README.md
```

## Requirements

- MATLAB/Simulink (developed on R2024b/R2025a-era releases)
- Stateflow (for the Coulomb Counting flag logic)
- No additional toolboxes required to run the core model standalone

## Getting started

1. Run `Guardian_Battery_script.m` first — loads the drive-cycle/OCV data, defines every model constant (no magic numbers in the model itself), computes the Ts-rescaled hysteresis filter coefficients, and defines the two bus objects.
2. Open `Guardian_Battery.slx`.
3. Confirm the solver: **Fixed-step, discrete, Ts = 0.1 s**.
4. In `TLS_RO_SOH_block`'s Variant Subsystem, set the Model Workspace variable `TLS_impl_select` (`1` = Coupled, `2` = Open-loop) to choose which R0/SOH identifier runs.
5. Run.

## Interfaces

| Bus | Elements | Scope |
|---|---|---|
| `BatteryDataBus` | `R0_TLS`, `SOH_ratio`, `SOC_EKF`, `SOC_Flag`, `V_terminal` | Public — the model's `Battery_data` outport |
| `GuardianCellBus` | Adds `SOC_CC`, `SOC_hat`, `V1_hat`, `V2_hat` | Internal-only, inside `Cell_DigitalTwin` |

## Validated results

- **SOC**: Coulomb Counting and the EKF's `SOC_hat` agree within a fraction of a percent across a full drive cycle.
- **R0 identification**: converges to and holds close to the true `R0_ref = 0.0007 Ω`.
- **SOH ratio**: stays within roughly a 95–104% band (rubric acceptance: 90–105% for a healthy, unaged cell).

## Known design notes

- The Coupled and Open-loop TLS variants trade off differently: Coupled shows a small structural bias with visually tighter output; Open-loop removes that bias but more directly exposes the underlying measurement noise. Neither is unconditionally "better" — see the full documentation for the analysis.
- Full development history (every non-obvious bug found and fixed, with root causes) is in `Guardian_Battery_ECM_Documentation.docx`.

## Related

This model is referenced as a Model Reference in **[Guardian_Mission](../Guardian_Mission)**, the capstone integration combining this battery digital twin with an autonomous rover's guidance layer under a Stateflow mission supervisor.
