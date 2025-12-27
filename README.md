# < 8x8 2D-DCT >
This repository contains the Verilog HDL implementation for a high-performance 8x8 Forward 2D Discrete Cosine Transform (2D-DCT) core design.The architecture is specifically optimized to interface with the TM.v verification environment, processing 256x256 grayscale Lena image data.

### <ins>Design Features<ins>
- Methodology: Implements 2D-DCT using the Row-Column Decomposition technique.
- High Throughput: Features a pipelined architecture designed to meet a 500 MHz timing constraint.
- Precision: Optimized for a Peak Signal-to-Noise Ratio (PSNR) $\ge$ 40dB, balancing hardware area with numerical accuracy.
- Hardware Efficiency: Uses a 4-stage pipelined 1D-DCT submodule and Ping-Pong Buffers for efficient matrix transposition.

### <ins>Architecture Overview<ins>
The design follows a modular approach to transform an $8 \times 8$ pixel block $f(x,y)$ into frequency coefficients $F(u,v)$.

**- Top Module (2D-DCT)**

The top-level design coordinates data flow through six primary stages:
1. Input Extension: Performs sign extension on 9-bit input data to 12-bit to prevent overflow during intermediate calculations.
2. Row DCT: Executes 1D-DCT across the rows of the $8 \times 8$ block.
3. Transpose Buffer 1: Utilizes Dual-Port RAM in a Ping-Pong configuration to transpose the row results.
4. Column DCT: Executes 1D-DCT across the columns.
5. Transpose Buffer 2: Performs the second matrix transposition to restore the correct output order.
6. Output Assignment: Outputs the final 18-bit coefficients accompanied by a ready signal.

**- Submodule (1D-DCT)**

The 1D-DCT core is implemented as a 4-stage pipeline:
- Stage 1 (Butterflies): Executes addition and subtraction to separate even and odd components.
- Stage 2 (Multipliers): Fixed-point multiplication of data with pre-calculated DCT coefficients.
- Stage 3 (Adders): Aggregates the multiplication products.
- Stage 4 (Shifter & Output): Scales the result by shifting right 14 bits to compensate for coefficient scaling.

### <ins>Specifications<ins>

<table>
  <tr>
    <td>Table</td>
    <td>Port Name</td>
    <td>Length</td>
  </tr>
  <tr>
    <td>Input</td>
    <td>x0 ~ x7</td>
    <td>9-bit</td>
    <td>signed bit</td>
  </tr>
    <td>Input</td>
    <td>clk</td>
    <td>1-bit</td>
  </tr>
    <td>Input</td>
    <td>rst_n</td>
    <td>1-bit</td>
    <td>Negative reset</td>
  </tr>
    <td>Output</td>
    <td>z0 ~ z7</td>
    <td>18-bit</td>
    <td>signed bit</td>
  </tr>
    <td>Output</td>
    <td>ready</td>
    <td>1-bit</td>
    <td>Output data ready set to 1'b1</td>
  </tr>
</table>

### <ins>Verification<ins>

Functionality and precision were verified by reconstructing the image through a software-based Inverse DCT (IDCT).

### <ins>Hardware Performance<ins>

The design was synthesized using ADFP with the following results (Note: Due to the confidentiality of the ADFP process, only the synthesis results are provided.):
- Power Consumption: 9.2312 mW.
- Timing: Achieved positive slack of 0.86 at the target frequency.
- Total Area: 14728.94 units.
