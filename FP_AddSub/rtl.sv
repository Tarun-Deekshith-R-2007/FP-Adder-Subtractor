`timescale 1ns/1ps
module fp_addsub (
    input logic clk, reset, in_valid, sub,
    input logic [31:0] a, b,
    output logic out_valid,
    output logic [31:0] result
);
    // Keep guard, round and sticky bits during alignment and arithmetic.
    function automatic [26:0] shift_jam(input [26:0] x, input integer n);
        integer j;
        reg sticky;
        reg [26:0] shifted;
        begin
            sticky = 1'b0;
            shifted = 27'b0;
            if (n >= 27) shifted = {26'b0, |x};
            else if (n == 0) shifted = x;
            else begin
                shifted = x >> n;
                for (j = 0; j < 27; j = j + 1)
                    if (j < n) sticky = sticky | x[j];
                shifted[0] = shifted[0] | sticky;
            end
            shift_jam = shifted;
        end
    endfunction

    reg [31:0] next_result;
    reg sa, sb, sign_z;
    reg [7:0] ea, eb;
    reg [23:0] ma, mb;
    reg [26:0] larger, lesser, normalized;
    reg [27:0] total;
    reg [24:0] rounded;
    reg [7:0] packed_exp;
    integer exp_a, exp_b, exp_z, k;

    always_comb begin
        sa = a[31];
        sb = b[31] ^ sub;
        ea = a[30:23];
        eb = b[30:23];
        ma = {(|ea), a[22:0]};
        mb = {(|eb), b[22:0]};
        exp_a = (ea == 0) ? 1 : {24'b0, ea};
        exp_b = (eb == 0) ? 1 : {24'b0, eb};
        larger = 0; lesser = 0; normalized = 0;
        total = 0; rounded = 0; packed_exp = 0;
        sign_z = 0; exp_z = 0; next_result = 0;
        k = 0;

        if ((ea == 255 && a[22:0] != 0) ||
            (eb == 255 && b[22:0] != 0))
            next_result = 32'h7fc00000;
        else if (ea == 255 && eb == 255 && sa != sb)
            next_result = 32'h7fc00000;
        else if (ea == 255) next_result = {sa, 8'hff, 23'b0};
        else if (eb == 255) next_result = {sb, 8'hff, 23'b0};
        else begin
            // Order by magnitude before subtraction, including subnormals.
            if (exp_a > exp_b || (exp_a == exp_b && ma >= mb)) begin
                larger = {ma, 3'b0};
                lesser = shift_jam({mb, 3'b0}, exp_a - exp_b);
                exp_z = exp_a;
                sign_z = sa;
            end else begin
                larger = {mb, 3'b0};
                lesser = shift_jam({ma, 3'b0}, exp_b - exp_a);
                exp_z = exp_b;
                sign_z = sb;
            end
            if (sa == sb) total = {1'b0, larger} + {1'b0, lesser};
            else total = {1'b0, larger} - {1'b0, lesser};

            if (total == 0) next_result = {sa & sb, 31'b0};
            else begin
                if (total[27]) begin
                    normalized = total[27:1];
                    normalized[0] = total[1] | total[0];
                    exp_z = exp_z + 1;
                end else normalized = total[26:0];
                // Bounded loop synthesizes without data-dependent iteration.
                for (k = 0; k < 26; k = k + 1) begin
                    if (!normalized[26] && exp_z > 1) begin
                        normalized = normalized << 1;
                        exp_z = exp_z - 1;
                    end
                end
                rounded = {1'b0, normalized[26:3]} +
                          {24'b0, (normalized[2] &&
                          (normalized[1] || normalized[0] || normalized[3]))};
                if (rounded[24]) begin
                    rounded = rounded >> 1;
                    exp_z = exp_z + 1;
                end
                if (exp_z >= 255) next_result = {sign_z, 8'hff, 23'b0};
                else begin
                    packed_exp = (exp_z == 1 && !rounded[23]) ? 8'b0 : exp_z[7:0];
                    next_result = {sign_z, packed_exp, rounded[22:0]};
                end
            end
        end
    end

    always @(posedge clk) begin
        if (reset) begin
            out_valid <= 1'b0;
            result <= 32'b0;
        end else begin
            out_valid <= in_valid;
            if (in_valid) result <= next_result;
        end
    end
endmodule
