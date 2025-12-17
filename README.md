# Hardware Accelerator for 1D CNN based Time Series Anomaly Detection

## 📌 Project Overview
[cite_start]This project implements a hardware accelerator for a **1-Dimensional Convolutional Neural Network (1D CNN)** using **Verilog HDL**[cite: 9, 48]. [cite_start]Designed for the **Industrial Internet of Things (IIoT)**, this accelerator enables real-time anomaly detection on edge devices (like FPGAs) without relying on cloud processing[cite: 44, 46].

[cite_start]The system processes time-series vibration data to classify the operational state of industrial motors into three categories[cite: 49]:
1. **Healthy** (Class 0)
2. **Bearing Fault** (Class 1)
3. **Rotor Imbalance** (Class 2)

## 🚀 Why Hardware Acceleration?
In industrial settings, sensors generate massive amounts of data. [cite_start]Relying solely on the cloud for analysis causes **latency** (delays), consumes **bandwidth**, and raises **security concerns**[cite: 46, 73].
By building a dedicated circuit (Hardware Accelerator) to run the AI model directly on the device, we achieve:
* [cite_start]**Low Latency:** Immediate fault detection critical for emergency shutdowns[cite: 74].
* [cite_start]**Data Privacy:** Sensitive operational data stays on the device[cite: 79].
* [cite_start]**Reliability:** Works even without an internet connection[cite: 80].

---

## 🧠 The AI Model Architecture
[cite_start]The hardware implements a specific feed-forward neural network designed for short time-series sequences[cite: 110]:

1. [cite_start]**Input Layer:** Takes in a sequence of **8 sensor samples**[cite: 112].
2. [cite_start]**Conv1D Layer:** Applies filters (kernels) to extract temporal features from the vibration data[cite: 118].
3. [cite_start]**ReLU Activation:** Removes negative values to introduce non-linearity ($f(x) = max(0, x)$)[cite: 122].
4. [cite_start]**Dense (Fully Connected) Layer:** Maps the features to the final 3 output classes[cite: 125].
5. [cite_start]**Output:** A classification score indicating the motor's health status[cite: 129].

---

## ⚙️ Hardware Architecture & Methodology
The project translates the AI model into digital logic circuits. [cite_start]The design is modular, controlled by **Finite State Machines (FSMs)** to manage the flow of data[cite: 135].

### 📂 Key Verilog Modules
* **`cnn_top.v` (Master Controller):**
  This is the "Brain" of the accelerator. [cite_start]It coordinates the entire process by triggering the Convolution layer, moving data through the ReLU activation, triggering the Dense layer, and outputting the final result[cite: 159, 171].

* **`mac_unit.v` (The Calculator):**
  A pipelined **Multiply-Accumulate** unit. [cite_start]Since Neural Networks are mostly multiplication and addition, this unit is optimized to do these calculations quickly using a 3-stage pipeline[cite: 177, 180].

* **`dual_port_bram.v` (Memory):**
  [cite_start]On-chip memory (Block RAM) used to store input sensor data, network weights (learned parameters), and intermediate features passed between layers[cite: 165].

* **`conv1d_bram_fsm.v`:**
  A dedicated controller for the Convolutional Layer. [cite_start]It manages the "sliding window" calculation over the input data[cite: 196, 202].

* **`compute_dense_fsm.v`:**
  A dedicated controller for the Dense Layer. [cite_start]It performs the matrix multiplication required to produce the final classification scores[cite: 216].

* **`compute_relu.v`:**
  A simple logic block that checks if a number is negative. [cite_start]If it is, it converts it to zero[cite: 211].

---

## 🔄 How It Works (Execution Flow)
[cite_start]When the accelerator is started, the `cnn_top` module orchestrates the following pipeline[cite: 138, 236]:

1. **Data Loading:** Input sensor data and model weights are loaded into the BRAMs (simulated via testbench).
2. **Convolution:** The `conv1d_bram_fsm` reads data, calculates features using the `mac_unit`, and signals when done.
3. **Activation:** `cnn_top` reads the convolution results, passes them through `compute_relu`, and writes the activated data to the intermediate memory.
4. **Classification:** `compute_dense_fsm` reads the activated features, calculates scores for all 3 classes, and identifies the maximum score.
5. **Result:** The system outputs `final_class_out` (0, 1, or 2).

---

## 🛠️ Simulation & Verification
[cite_start]The design was verified using the **Xilinx Vivado Simulator**[cite: 251].

### Test Strategy
We created comprehensive testbenches (`cnn_top_tb_comprehensive.v`) that:
1. [cite_start]Load the memory with synthetic data[cite: 265].
2. [cite_start]Load specific weights designed to force the network to detect specific faults[cite: 277].
3. Run the accelerator.
4. [cite_start]Automatically compare the hardware output against the expected mathematical result[cite: 271].

### Results
[cite_start]The simulation successfully verified the logic for all three cases[cite: 290, 292, 294]:
* ✅ **Case 0:** Correctly identified "Healthy" state.
* ✅ **Case 1:** Correctly identified "Bearing Fault".
* ✅ **Case 2:** Correctly identified "Rotor Imbalance".

---

## 🔮 Future Scope
* [cite_start]**Hardware Implementation:** Synthesize the design onto a physical FPGA board (e.g., Xilinx Artix-7/Zynq)[cite: 533].
* [cite_start]**Real-time Inputs:** Integrate an Analog-to-Digital Converter (ADC) to read real vibration sensors[cite: 537].
* [cite_start]**Processor Integration:** Add an AXI-Lite interface to allow a CPU to communicate with the accelerator[cite: 538].

---
