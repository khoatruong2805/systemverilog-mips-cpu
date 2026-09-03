`timescale 1ns / 1ps // Định nghĩa đơn vị thời gian (1ns) và độ phân giải (1ps)

module datapath_single_cycle_tb();

    // ==========================================
    // 1. KHAI BÁO TÍN HIỆU
    // ==========================================
    logic clk;
    logic rst;

    // ==========================================
    // 2. KHỞI TẠO BỘ VI XỬ LÝ (DATAPATH)
    // ==========================================
    datapath_single_cycle u_cpu(
        .clk(clk),
        .rst(rst)
    );

    // ==========================================
    // 3. TẠO XUNG NHỊP (CLOCK GENERATOR)
    // ==========================================
    // Cứ sau 5ns thì đảo trạng thái clk 1 lần -> Chu kỳ = 10ns
    always #5 clk = ~clk;

    // ==========================================
    // 4. KỊCH BẢN CHẠY MÔ PHỎNG (STIMULUS)
    // ==========================================
    initial begin
        // A. Cấu hình xuất file sóng (Waveform) cho Icarus Verilog / GTKWave
        $dumpfile("waveform.vcd");
        $dumpvars(0, datapath_single_cycle_tb);

        // B. Nạp chương trình vào bộ nhớ ROM
        // Chọc mũi kim vào mảng rom bên trong u_instruction_mem để bơm data
        $readmemh("tb/machine_code.txt", u_cpu.u_instruction_mem.rom);

        // C. Quá trình Reset hệ thống
        clk = 0;
        rst = 1;     // Kéo rst lên 1 để Program Counter reset về 0
        #10;         // Đợi 10ns (1 chu kỳ)
        rst = 0;     // Nhả rst về 0, CPU CHÍNH THỨC BẮT ĐẦU CHẠY!

        // D. Thời gian chạy
        // Cho chạy 200ns (tương đương 20 chu kỳ clock / 20 lệnh) rồi dừng
        #200;
        $display("----------------------------------------");
        $display("Hoan tat mo phong!");
        $finish;
    end

    // ==========================================
    // 5. THEO DÕI TÍN HIỆU (MONITOR)
    // ==========================================
    // Lệnh này sẽ tự động in ra màn hình mỗi khi có 1 biến bị thay đổi giá trị
    initial begin
        $display("Time\t | rst | PC\t\t | Instruction\t | ALU_Result");
        $monitor("%0t\t |  %b  | %h\t | %h\t | %h", 
                 $time, rst, u_cpu.current_pc, u_cpu.instruction, u_cpu.alu_result);
    end

endmodule