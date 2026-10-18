# MIPS pipeline 5 tầng

Thiết kế học tập: IF → ID → EX → MEM → WB; `beq` quyết định ở MEM,
`j` quyết định ở ID; **không có delay slot**. Branch già hơn ưu tiên jump và stall.

## Tập lệnh và giới hạn

- Hỗ trợ `add`, `sub`, `and`, `or`, `slt`, `addi`, `andi`, `ori`, `slti`,
  `lw`, `sw`, `beq`, `j`, `nop`.
- Đây là MIPS subset, không phải toàn bộ ISA. Không có exception/overflow trap,
  interrupt, cache, byte/halfword access, `jal`, `jr`, multiply/divide hay HI/LO.
  ADD/SUB/ADDI hiện tính modulo 2^32. Opcode/funct chưa hỗ trợ không gây ghi.
- ROM và RAM riêng biệt, mỗi vùng 64 word (256 byte). Địa chỉ byte, word-aligned.
  Instruction fetch và RAM read là tổ hợp; RAM write ở cạnh lên. Nếu đổi sang
  block RAM đọc đồng bộ trên FPGA, phải thiết kế lại timing/hazard tương ứng.
- Reset đồng bộ mức cao: PC, pipeline register và register file về 0;
  RAM giữ nguyên. Chặn RAM/register write trong reset.
- `$0` luôn bằng 0. Chương trình tự nạp hằng số vào các register khác.
- ROM mặc định đọc `program.txt`, vùng chưa nạp điền NOP; fetch không hợp lệ
  trả X, không wrap địa chỉ. Đặt `PROGRAM_FILE=""` khi TB tự nạp ROM.
- RAM chưa ghi không có giá trị khởi tạo mặc định. Test phải nạp trước khi đọc.
  Mô phỏng báo `$fatal` cho load/store lệch hàng, vượt vùng hoặc địa chỉ X.
  Đây là kiểm tra mô phỏng, không phải exception phần cứng.

## Hazard và flush

- EX/MEM forwarding ưu tiên MEM/WB; WB forwarding lấy dữ liệu sau mux MemToReg.
- Register file có bypass WB → ID cho đọc/ghi cùng chu kỳ.
- Load-use: giữ PC/IF_ID, tạo bubble ID_EX, cho load đi tiếp.
  Chỉ xét các thanh ghi nguồn thực sự và bỏ qua destination `$0`.
- Load → store data cần một stall trong thiết kế này.
- Branch taken: redirect PC; flush IF_ID, ID_EX, EX_MEM; giữ MEM_WB.
- Jump: redirect PC; flush IF_ID và ID_EX; giữ các lệnh già hơn.

## Chạy kiểm tra

Trong WSL Ubuntu, cài sẵn Python 3 và Icarus Verilog (`iverilog`, `vvp`):

```bash
cd /home/khoa_truong2805/sv_project/pipelined
python3 run_tests.py
```

Script chạy từ bất kỳ working directory nào, tự đặt cwd đúng để đọc ROM.
Binary và log mới nằm trong `build/`. Suite trả exit code khác 0 nếu lỗi,
compile thất bại hoặc vượt timeout. Không dùng các binary cũ ở thư mục gốc.

- `tb/pipeline_tb.sv`: demo đọc `program.txt`; kiểm tra r3=15, r4=15,
  r5=20 và memory[0]=15. Demo có forwarding, store, load-use và jump loop.
- `tb/pipeline_regression_tb.sv`: 19 chương trình directed, 20 chương trình
  pseudo-random seed cố định, reset giữa chương trình và chạy lại sau reset:
  tổng 41 trường hợp. Oracle tuần tự đối chiếu thứ tự, đích và giá trị của
  từng lần ghi register/memory, rồi so sánh toàn bộ trạng thái cuối.
  Monitor kiểm tra stall giữ PC/IF_ID, bubble, flush và ưu tiên redirect.
- `tb/memory_guard_tb.sv`: 5 trường hợp truy cập bộ nhớ sai. Các dòng FATAL
  trong suite này là kết quả mong đợi; script kiểm tra đúng thông báo và exit code.

Bao phủ directed: EX/MEM/WB forwarding cả hai operand, WB→ID, producer mới nhất,
load→ALU/store/address, offset âm, false stall, `$0`, branch taken/not taken,
load→branch, branch+stall, jump, branch+jump, logical immediate bit 15=1,
signed compare, các phép R-type, branch lùi, NOP/unsupported, word cuối RAM,
reset với store ở MEM và register write ở WB, restart.

Kết quả kiểm tra hiện tại: 41 cases / 14357 checks PASS, demo PASS,
5 memory guards được bắt đúng. Các test này không phải chứng minh hình thức
hay kiểm tra toàn bộ mọi tổ hợp chương trình.

Tạo waveform demo sau khi chạy suite:

```bash
vvp build/demo.vvp +VCD
gtkwave cpu_pipeline_sim.vcd
```
