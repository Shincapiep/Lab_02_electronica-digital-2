`timescale 1ns / 1ps
// ============================================================
// Lab02 - Modulo superior (datapath) de la ALU de 4 bits
//  - Registros A y B: se cargan con SW mientras BTN0 / BTN1 esten presionados
//  - Registro C (opcode): BTN2 invierte C[0], BTN3 invierte C[1]
//    y el valor se conserva al soltar los botones
//  - La ALU (combinacional) esta en un modulo aparte
//  - LED RGB indica la operacion almacenada en C
//
// Sin modulo de antirrebote: BTN2 y BTN3 se muestrean cada N_TICK ciclos
// (10 ms a 125 MHz). El rebote dura menos que eso, asi que entre dos
// muestras solo se ve un cambio por pulsacion.
// ============================================================
module datapath #(
    parameter integer N_TICK = 1250000      // 10 ms a 125 MHz
)(
    input            clk,
    input      [3:0] SW,
    input      [3:0] BTNS,
    output     [3:0] LED,
    output reg       LED_R, LED_G, LED_B
);

    localparam [1:0] SUM_OP = 2'b00;
    localparam [1:0] RES_OP = 2'b01;
    localparam [1:0] AND_OP = 2'b10;
    localparam [1:0] OR_OP  = 2'b11;

    //------------------------------------------------
    // Registros del sistema (valores iniciales = estado de arranque)
    //------------------------------------------------
    reg [3:0] A = 4'd0;
    reg [3:0] B = 4'd0;
    reg [1:0] C = SUM_OP;
    wire [3:0] Z;

    //------------------------------------------------
    // Sincronizador de 2 flip-flops para los botones
    //------------------------------------------------
    reg [3:0] btn_s0 = 4'b0000;
    reg [3:0] btn_s1 = 4'b0000;

    always @(posedge clk) begin
        btn_s0 <= BTNS;
        btn_s1 <= btn_s0;
    end

    //------------------------------------------------
    // Registros A y B
    //------------------------------------------------
    always @(posedge clk) begin
        if (btn_s1[0]) A <= SW;
        if (btn_s1[1]) B <= SW;
    end

    //------------------------------------------------
    // Base de tiempo para muestrear BTN2 y BTN3
    //------------------------------------------------
    integer cnt  = 0;
    reg     tick = 1'b0;

    always @(posedge clk) begin
        if (cnt == N_TICK - 1) begin
            cnt  <= 0;
            tick <= 1'b1;
        end else begin
            cnt  <= cnt + 1;
            tick <= 1'b0;
        end
    end

    //------------------------------------------------
    // Registro del codigo de operacion C
    // En cada tick se compara la muestra actual con la anterior:
    // si paso de 0 a 1 (pulsacion), se invierte el bit correspondiente
    //------------------------------------------------
    reg [3:2] btn_m = 2'b00;   // muestra anterior de BTN3, BTN2

    always @(posedge clk) begin
        if (tick) begin
            if (btn_s1[2] & ~btn_m[2]) C[0] <= ~C[0];   // BTN2 -> bit 0
            if (btn_s1[3] & ~btn_m[3]) C[1] <= ~C[1];   // BTN3 -> bit 1
            btn_m <= btn_s1[3:2];
        end
    end

    //------------------------------------------------
    // ALU combinacional (modulo independiente)
    //------------------------------------------------
    ALU calll (
        .A    (A),
        .B    (B),
        .OP   (C),
        .OUTT (Z)
    );

    assign LED = Z;

    //------------------------------------------------
    // Indicador de operacion en el LED RGB
    //------------------------------------------------
    always @(*) begin
        case (C)
            SUM_OP:  {LED_R, LED_G, LED_B} = 3'b010;   // Verde
            RES_OP:  {LED_R, LED_G, LED_B} = 3'b100;   // Rojo
            AND_OP:  {LED_R, LED_G, LED_B} = 3'b001;   // Azul
            OR_OP:   {LED_R, LED_G, LED_B} = 3'b011;   // Cian (G + B)
            default: {LED_R, LED_G, LED_B} = 3'b000;
        endcase
    end

endmodule
