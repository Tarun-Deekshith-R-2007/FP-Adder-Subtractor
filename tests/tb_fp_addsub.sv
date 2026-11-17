`timescale 1ns/1ps
module tb_fp_addsub;
    reg clk = 0;
    always #5 clk = ~clk;
    reg reset = 1, in_valid = 0, sub = 0;
    reg [31:0] a = 0, b = 0;
    wire out_valid;
    wire [31:0] result;
    reg [31:0] va, vb, expected, held;
    reg vs;
    integer fd, rc, count = 0;
    fp_addsub dut(.*);
    initial begin
        if ($test$plusargs("vcd")) begin
            $dumpfile("build/fp_addsub.vcd");
            $dumpvars(0, tb_fp_addsub);
        end
        repeat (3) begin
            @(posedge clk); #1;
            if (out_valid !== 0 || result !== 0) $fatal(1, "Reset failed");
        end
        @(negedge clk); reset = 0;
        fd = $fopen("build/vectors.txt", "r");
        if (fd == 0) $fatal(1, "Cannot open vectors");
        while (!$feof(fd)) begin
            rc = $fscanf(fd, "%h %h %h %h\n", va, vb, vs, expected);
            if (rc != 4) $fatal(1, "Malformed vector");
            @(negedge clk);
            a = va; b = vb; sub = vs; in_valid = 1;
            @(posedge clk); #1;
            if (out_valid !== 1 || result !== expected)
                $fatal(1, "Vector %0d a=%h b=%h sub=%b expected=%h got=%h valid=%b",
                       count, va, vb, vs, expected, result, out_valid);
            // Destroy inputs immediately after capture; output must be registered.
            a = ~va; b = ~vb; sub = ~vs;
            #1;
            if (result !== expected) $fatal(1, "Result depends on live operands");
            held = result;
            @(negedge clk); in_valid = 0;
            repeat (2) begin
                @(posedge clk); #1;
                if (out_valid !== 0 || result !== held) $fatal(1, "Idle failed");
            end
            count = count + 1;
        end
        // Reset wins over a simultaneous valid transaction, including mid-run.
        @(negedge clk); reset = 1; in_valid = 1;
        @(posedge clk); #1;
        if (out_valid !== 0 || result !== 0) $fatal(1, "Reset priority failed");
        @(negedge clk); reset = 0; a = 32'h3f800000; b = 32'h3f800000; sub = 0;
        @(posedge clk); #1;
        if (out_valid !== 1 || result !== 32'h40000000) $fatal(1, "Recovery failed");
        // Consecutive valid edges are supported as an extra capability.
        @(negedge clk); sub = 1;
        @(posedge clk); #1;
        if (out_valid !== 1 || result !== 0) $fatal(1, "Back-to-back failed");
        $display("PASS: %0d arithmetic vectors, reset, idle, input capture and consecutive requests", count);
        $fclose(fd);
        $finish;
    end
endmodule
