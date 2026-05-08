# 🚦 FPGA Traffic Light Controller (Basys3)

A **Verilog HDL** traffic light controller for the **Basys3 FPGA** that supports both **Automatic** and **Manual** modes.  
LEDs indicate North–South (NS) and East–West (EW) signals, while the **rightmost 7-segment display** shows a countdown timer for each phase.

---


 
## 🔧 Features

- ✅ **Dual Modes**
  - **Automatic (SW1 = 1):** Cycles through traffic phases with a visible countdown.
  - **Manual (SW1 = 0):** Advance one phase per press using **BTN Right**.
- ⏯️ **Pause/Resume** in Automatic mode via **BTN Left**.
- 🔁 **Global Reset** via **BTN Center**.
- 🔌 **System ON/OFF** via **SW0**.
- 💡 **LED Mapping**
  - **NS** → `LED[2:0]` = `{Red, Yellow, Green}`
  - **EW** → `LED[15:13]` = `{Red, Yellow, Green}`
- 🕒 **7-Segment Timer**
  - Rightmost digit only, counts **5 → 0** (active-low segments on Basys3).

---

## 🧠 Controls at a Glance

| Component      | Purpose                                   |
|----------------|-------------------------------------------|
| **SW0**        | System ON/OFF                             |
| **SW1**        | Mode Select → `1 = Automatic`, `0 = Manual` |
| **BTN Center** | Reset system (async sync-safe recommended)|
| **BTN Left**   | Pause/Resume (Automatic only)             |
| **BTN Right**  | Next state (Manual only)                  |
| **LED[2:0]**   | NS lights `{R, Y, G}`                     |
| **LED[15:13]** | EW lights `{R, Y, G}`                     |
| **7-Segment**  | Countdown on rightmost digit              |

---

## ⚙️ Design Details

### Finite-State Machine (FSM)

1. `INITIAL_STATE` — All Red (safe start)  
2. `NS_GREEN_EW_RED`  
3. `NS_YELLOW_EW_RED`  
4. `NS_RED_EW_GREEN`  
5. `NS_RED_EW_YELLOW`  
…then loops back.

### Phase Durations (seconds)

| Phase  | Duration |
|--------|----------|
| Green  | 5        |
| Yellow | 1        |
| Red    | 5        |

> Tip: Make these **Verilog parameters** so you can tune timings without editing logic.

### Clocking

- Basys3 default clock: **100 MHz** (pin **W5**).
- Internal clock divider generates **1 Hz** ticks for second-based timing.
- Debounce/synchronize buttons to avoid metastability and unintended multiple edges.

### 7-Segment Display Notes (Basys3)

- 4-digit **common-anode** display.
- **Segments** and **digit enables** are **active-low**.
- This design enables **only the rightmost digit**; segments display the countdown value.

---

## 🗂️ Project Structure

```text
FPGA_Traffic_Light_Controller/
├─ src/
│  ├─ traffic_light_top.v            # Top-level integration: IO, clock div, debounce, mux
│  └─ traffic_light_controller.v     # FSM + timers + mode control
├─ testbench/                        # (Optional) TBs for FSM and top
├─ constraints/                      # Basys3 .xdc (pins: clock W5, LEDs, buttons, switches, 7-seg)
├─ docs/                             # Timing diagrams, state charts, notes
└─ README.md
```

---

## ▶️ Build & Run (Vivado)

1. **Create Project:** Add `src/` files; set board to **Basys3 (Artix-7 XC7A35T-1CPG236C)**.
2. **Add Constraints:** Use your Basys3 `.xdc` (clock **W5**, BTN/LED/SW pins, 7-seg pins).
3. **Synthesize & Implement:** Check timing (1 Hz logic derives from 100 MHz).
4. **Generate Bitstream** and **Program Device**.
5. **Operate:**
   - Set **SW0 = 1** to power logic.
   - Choose mode with **SW1**.
   - Use **BTN L/R/C** per the table above.

---

## 🧪 Simulation

- Use **Vivado** or **ModelSim**.
- For faster sims, **scale down** the clock divider (e.g., simulate 1 kHz→1 Hz instead of 100 MHz→1 Hz).
- Provide unit tests for:
  - Correct state ordering
  - Countdown accuracy
  - Pause behavior (Automatic)
  - Manual stepping edge cases (debounce)

---

## 🧮 FSM Transition Diagram (Textual)

```
INITIAL_STATE
   ↓
NS_GREEN_EW_RED → NS_YELLOW_EW_RED → NS_RED_EW_GREEN → NS_RED_EW_YELLOW
   ↺ (loops)
```

---

## 📷 Demo (Optional)

Add photos or short GIFs showing:
- LED patterns per state
- 7-segment countdown
- Pause/Resume and Manual step behavior

---

## 🚀 Roadmap

- 🚶 Pedestrian crossing inputs and walk timers  
- 🧠 Sensor-based adaptive timing (traffic density)  
- 🖥️ Extended 7-segment usage (full state names / dual-direction timing)  

---

## 👨‍💻 Authors

**Samun Sadab Wafi & Efat Ara Belly**  
Department of Computer Science & Engineering, 
Khulna University of Engineering & Technology


---

## 🏷️ Tags

`#FPGA` `#Verilog` `#Basys3` `#TrafficLightController` `#DigitalDesign` `#FSM` `#HDL`
