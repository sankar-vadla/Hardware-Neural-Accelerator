# Hardware Accelerator for 1D CNN based Time Series Anomaly Detection

##  Project Overview
This project implements a hardware accelerator for a **1-Dimensional Convolutional Neural Network (1D CNN)** using **Verilog HDL**. Designed for the **Industrial Internet of Things (IIoT)**, this accelerator enables real-time anomaly detection on edge devices (like FPGAs) without relying on cloud processing.
The system processes time-series vibration data to classify the operational state of industrial motors into three categories:
1. **Healthy** (Class 0)
2. **Bearing Fault** (Class 1)
3. **Rotor Imbalance** (Class 2)

##  Why Hardware Acceleration?
In industrial settings, sensors generate massive amounts of data. Relying solely on the cloud for analysis causes **latency** (delays), consumes **bandwidth**, and raises **security concerns**.
By building a dedicated circuit (Hardware Accelerator) to run the AI model directly on the device, we achieve:
* **Low Latency:** Immediate fault detection critical for emergency shutdowns.
* **Data Privacy:** Sensitive operational data stays on the device.
* **Reliability:** Works even without an internet connection.

---

##  The AI Model Architecture
The hardware implements a specific feed-forward neural network designed for short time-series sequences:

1. **Input Layer:** Takes in a sequence of **8 sensor samples**.
2. **Conv1D Layer:** Applies filters (kernels) to extract temporal features from the vibration data.
3. **ReLU Activation:** Removes negative values to introduce non-linearity ($f(x) = max(0, x)$).
4. **Dense (Fully Connected) Layer:** Maps the features to the final 3 output classes.
5. **Output:** A classification score indicating the motor's health status.

---

##  Hardware Architecture & Methodology
The project translates the AI model into digital logic circuits. [cite_start]The design is modular, controlled by **Finite State Machines (FSMs)** to manage the flow of data.

###  Key Verilog Modules
* **`cnn_top.v` (Master Controller):**
  This is the "Brain" of the accelerator. It coordinates the entire process by triggering the Convolution layer, moving data through the ReLU activation, triggering the Dense layer, and outputting the final result.

* **`mac_unit.v` (The Calculator):**
  A pipelined **Multiply-Accumulate** unit. Since Neural Networks are mostly multiplication and addition, this unit is optimized to do these calculations quickly using a 3-stage pipeline.

* **`dual_port_bram.v` (Memory):**
  On-chip memory (Block RAM) used to store input sensor data, network weights (learned parameters), and intermediate features passed between layers.

* **`conv1d_bram_fsm.v`:**
  A dedicated controller for the Convolutional Layer. It manages the "sliding window" calculation over the input data.

* **`compute_dense_fsm.v`:**
  A dedicated controller for the Dense Layer. It performs the matrix multiplication required to produce the final classification scores.

* **`compute_relu.v`:**
  A simple logic block that checks if a number is negative. If it is, it converts it to zero.

---

##  How It Works (Execution Flow)
When the accelerator is started, the `cnn_top` module orchestrates the following pipeline:

1. **Data Loading:** Input sensor data and model weights are loaded into the BRAMs (simulated via testbench).
2. **Convolution:** The `conv1d_bram_fsm` reads data, calculates features using the `mac_unit`, and signals when done.
3. **Activation:** `cnn_top` reads the convolution results, passes them through `compute_relu`, and writes the activated data to the intermediate memory.
4. **Classification:** `compute_dense_fsm` reads the activated features, calculates scores for all 3 classes, and identifies the maximum score.
5. **Result:** The system outputs `final_class_out` (0, 1, or 2).

---

##  Simulation & Verification
The design was verified using the **Xilinx Vivado Simulator**.

### Test Strategy
We created comprehensive testbenches (`cnn_top_tb_comprehensive.v`) that:
1. Load the memory with synthetic data.
2. Load specific weights designed to force the network to detect specific faults.
3. Run the accelerator.
4. Automatically compare the hardware output against the expected mathematical result.

### Results
The simulation successfully verified the logic for all three cases:
*  **Case 0:** Correctly identified "Healthy" state.
*  **Case 1:** Correctly identified "Bearing Fault".
*  **Case 2:** Correctly identified "Rotor Imbalance".

---

##  Future Scope
* **Hardware Implementation:** Synthesize the design onto a physical FPGA board (e.g., Xilinx Artix-7/Zynq).
* **Real-time Inputs:** Integrate an Analog-to-Digital Converter (ADC) to read real vibration sensors.
* **Processor Integration:** Add an AXI-Lite interface to allow a CPU to communicate with the accelerator.

---
