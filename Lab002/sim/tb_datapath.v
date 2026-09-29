`timescale 1ns / 1ps
// ============================================================
// Testbench autoverificable del datapath (Lab02)
//  - Reloj de 125 MHz (8 ns), igual al de la Zybo Z7
//  - N_TICK reducido a 20 ciclos para que la simulacion sea corta
//  - Las pulsaciones de BTN2/BTN3 incluyen rebote simulado
// ============================================================
module tb_datapath;

    localparam integer N_TICK = 20;

    reg        clk  = 1'b0;
    reg  [3:0] SW   = 4'd0;
    reg  [3:0] BTNS = 4'd0;
    wire [3:0] LED;
    wire       LED_R, LED_G, LED_B;

    integer errores = 0;

    datapath #(.N_TICK(N_TICK)) dut (
        .clk   (clk),
        .SW    (SW),
        .BTNS  (BTNS),
        .LED   (LED),
        .LED_R (LED_R),
        .LED_G (LED_G),
        .LED_B (LED_B)
    );

    always #4 clk = ~clk;   // 125 MHz

    //------------------------------------------------
    // Esperar varios periodos de muestreo
    //------------------------------------------------
    task esperar;
        begin
            repeat (5 * N_TICK) @(posedge clk);
        end
    endtask

    //------------------------------------------------
    // Pulsacion con rebote: el boton oscila unos ciclos
    // al presionar y al soltar
    //------------------------------------------------
    task press_btn;
        input integer idx;
        integer k;
        begin
            for (k = 0; k < 4; k = k + 1) begin
                BTNS[idx] = 1; repeat (3) @(posedge clk);
                BTNS[idx] = 0; repeat (2) @(posedge clk);
            end
            BTNS[idx] = 1;
            esperar;
            for (k = 0; k < 4; k = k + 1) begin
                BTNS[idx] = 0; repeat (3) @(posedge clk);
                BTNS[idx] = 1; repeat (2) @(posedge clk);
            end
            BTNS[idx] = 0;
            esperar;
        end
    endtask

    //------------------------------------------------
    // Comparacion con el valor esperado
    //------------------------------------------------
    task verificar;
        input [8*16-1:0] caso;
        input [3:0]      a_esp, b_esp;
        input [1:0]      c_esp;
        input [3:0]      led_esp;
        input [2:0]      rgb_esp;     // {R, G, B}
        begin
            if (dut.A !== a_esp || dut.B !== b_esp || dut.C !== c_esp ||
                LED !== led_esp || {LED_R, LED_G, LED_B} !== rgb_esp) begin
                $display("ERROR %s: A=%0d B=%0d C=%b LED=%0d RGB=%b | esperado A=%0d B=%0d C=%b LED=%0d RGB=%b",
                         caso, dut.A, dut.B, dut.C, LED, {LED_R, LED_G, LED_B},
                         a_esp, b_esp, c_esp, led_esp, rgb_esp);
                errores = errores + 1;
            end else
                $display("OK    %s: A=%0d B=%0d C=%b LED=%0d RGB=%b",
                         caso, dut.A, dut.B, dut.C, LED, {LED_R, LED_G, LED_B});
        end
    endtask

    //------------------------------------------------
    // Estimulos
    //------------------------------------------------
    initial begin
        $dumpfile("tb_datapath.vcd");
        $dumpvars(0, tb_datapath);

        esperar;

        // Carga de operandos
        SW = 4'd5;  press_btn(0);
        SW = 4'd3;  press_btn(1);

        // Mover los switches sin cargar: A y B no deben cambiar
        SW = 4'd15; esperar;
        verificar("SUMA  5+3      ", 4'd5, 4'd3, 2'b00, 4'd8,  3'b010);

        press_btn(2);   // C = 01
        verificar("RESTA 5-3      ", 4'd5, 4'd3, 2'b01, 4'd2,  3'b100);

        press_btn(3);   // C = 11
        verificar("OR    5|3      ", 4'd5, 4'd3, 2'b11, 4'd7,  3'b011);

        press_btn(2);   // C = 10
        verificar("AND   5&3      ", 4'd5, 4'd3, 2'b10, 4'd1,  3'b001);

        // Nuevos operandos, con la operacion AND todavia seleccionada
        SW = 4'd9;  press_btn(0);
        SW = 4'd6;  press_btn(1);
        verificar("AND   9&6      ", 4'd9, 4'd6, 2'b10, 4'd0,  3'b001);

        press_btn(2);   // C = 11
        verificar("OR    9|6      ", 4'd9, 4'd6, 2'b11, 4'd15, 3'b011);

        press_btn(3);   // C = 01
        verificar("RESTA 9-6      ", 4'd9, 4'd6, 2'b01, 4'd3,  3'b100);

        press_btn(2);   // C = 00
        verificar("SUMA  9+6      ", 4'd9, 4'd6, 2'b00, 4'd15, 3'b010);

        $display("--------------------------------------------");
        if (errores == 0) $display("DATAPATH: PASO");
        else              $display("DATAPATH: FALLO - %0d errores", errores);
        $display("--------------------------------------------");
        $finish;
    end

endmodule
