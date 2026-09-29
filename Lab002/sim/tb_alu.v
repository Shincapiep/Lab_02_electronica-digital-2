`timescale 1ns / 1ps
// ============================================================
// Testbench autoverificable de la ALU (Lab02 - Ejercicio 2)
//  - Recorre las 4 operaciones con las 256 combinaciones de A y B
//  - Compara OUTT con un modelo de referencia
//  - Cambia OP con A y B fijos para ver la respuesta combinacional
// ============================================================
module tb_alu;

    reg  [3:0] A  = 4'd0;
    reg  [3:0] B  = 4'd0;
    reg  [1:0] OP = 2'b00;
    wire [3:0] OUTT;

    reg  [3:0] esperado;
    integer    op_i, a_i, b_i;
    integer    errores = 0;
    integer    pruebas = 0;

    ALU dut (
        .A    (A),
        .B    (B),
        .OP   (OP),
        .OUTT (OUTT)
    );

    // Modelo de referencia
    always @(*) begin
        case (OP)
            2'b00: esperado = A + B;
            2'b01: esperado = A - B;
            2'b10: esperado = A & B;
            2'b11: esperado = A | B;
        endcase
    end

    task revisar;
        begin
            pruebas = pruebas + 1;
            if (OUTT !== esperado) begin
                $display("ERROR: OP=%b A=%0d B=%0d -> OUTT=%0d, esperado %0d",
                         OP, A, B, OUTT, esperado);
                errores = errores + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("tb_alu.vcd");
        $dumpvars(0, tb_alu);

        //------------------------------------------------
        // Parte 1: casos representativos (para ver en GTKWave)
        // A y B fijos, se cambia solo OP
        //------------------------------------------------
        A = 4'd5; B = 4'd3;
        for (op_i = 0; op_i < 4; op_i = op_i + 1) begin
            OP = op_i; #10; revisar;
            $display("A=%0d B=%0d OP=%b -> OUTT=%b (%0d)", A, B, OP, OUTT, OUTT);
        end

        A = 4'd3; B = 4'd5;          // resta negativa: 3 - 5 = -2 -> 1110
        for (op_i = 0; op_i < 4; op_i = op_i + 1) begin
            OP = op_i; #10; revisar;
            $display("A=%0d B=%0d OP=%b -> OUTT=%b (%0d)", A, B, OP, OUTT, OUTT);
        end

        A = 4'd15; B = 4'd1;         // desbordamiento en la suma: 15 + 1 = 0
        for (op_i = 0; op_i < 4; op_i = op_i + 1) begin
            OP = op_i; #10; revisar;
            $display("A=%0d B=%0d OP=%b -> OUTT=%b (%0d)", A, B, OP, OUTT, OUTT);
        end

        //------------------------------------------------
        // Parte 2: prueba exhaustiva (4 x 16 x 16 = 1024 casos)
        //------------------------------------------------
        for (op_i = 0; op_i < 4; op_i = op_i + 1)
            for (a_i = 0; a_i < 16; a_i = a_i + 1)
                for (b_i = 0; b_i < 16; b_i = b_i + 1) begin
                    OP = op_i; A = a_i; B = b_i;
                    #1; revisar;
                end

        $display("--------------------------------------------");
        if (errores == 0) $display("ALU: PASO - %0d casos verificados", pruebas);
        else              $display("ALU: FALLO - %0d errores en %0d casos", errores, pruebas);
        $display("--------------------------------------------");
        $finish;
    end

endmodule
