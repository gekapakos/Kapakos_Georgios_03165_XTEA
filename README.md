# XTEA Block Cipher - SystemVerilog Implementation

## 🔐 What is XTEA?

XTEA (eXtended Tiny Encryption Algorithm) is a symmetric block cipher designed to address weaknesses in the original TEA algorithm. It is known for its simplicity and suitability for resource-constrained environments such as embedded systems and wireless sensor networks.

### 🧩 Key Features
- **Block Size:** 64 bits
- **Key Size:** 128 bits (16 bytes)
- **Rounds:** Typically 64 rounds
- **Operations:** Bitwise XOR, addition, and shifts
- **Security:** Improved over TEA, though not recommended for modern cryptographic applications (AES preferred)
- **Public Domain:** Open design and simple implementation

## 🧠 Algorithm Overview

- XTEA is a 64-round Feistel cipher.
- Operates on two 32-bit halves of data.
- Uses a 128-bit key divided into four 32-bit subkeys.
- Each round involves key mixing and mathematical transformations.


## ⚙️ Module Structure

### 🔷 `xtea.sv` (Top Module)
### 🔷 `xtea_core.sv` (Core Logic)

### 🧪 Testbench Modules:
- `tb_xtea.sv` (Top Testbench)
- `tb_xtea_core.sv` (Core Testbench)

### 🔍 Role of Assertions in the Project

The inclusion of **SystemVerilog assertions** significantly enhanced the reliability and robustness of the XTEA module during the development and verification phases.

#### ✅ Why Assertions Were Added:
- **Early Bug Detection:** Assertions helped catch design flaws and unexpected behaviors during simulation before synthesis.
- **Design Confidence:** They acted as *self-checks*, verifying that encryption/decryption processes, round counts, and control signals behaved as expected at each simulation cycle.
- **Improved Debugging:** Instead of manually tracing issues in waveforms, failing assertions directly highlighted where and why behavior diverged from the expected.

#### 📌 What They Checked:
- Stability of the **encryption/decryption result** after a given number of rounds.
- Correct transition of the **write enable (`we`)** signal after 16 rounds.
- That **read data (`read_data`)** was zero when expected or reflected the correct values.
- Accuracy of the **round counter**, ensuring no skipped or excess cycles.
- Consistency between **testbench values** and **internal logic signals**.

#### 💡 Impact on the Project:
By integrating assertions:
- **Verification time was reduced** due to automated property checking.
- **Design confidence increased**, knowing that runtime conditions were constantly monitored.
- **Code maintainability improved**, with assertions acting as both verification and live documentation for expected design behavior.

Assertions proved to be a critical component in ensuring the correctness and quality of the SystemVerilog-based XTEA implementation.

