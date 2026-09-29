`timescale 1ns / 1ps
// ============================================================
// Lab02 - ALU de 4 bits (logica puramente combinacional)
//
//   OP | Operacion
//   00 | A + B   (suma, sin acarreo: resultado modulo 16)
//   01 | A - B   (resta, complemento a 2: 3 - 5 = 1110)
//   10 | A & B   (AND bit a bit)
//   11 | A | B   (OR bit a bit)
//
// No tiene reloj ni registros: la salida depende solo de las
// entradas actuales. Todos los casos del case asignan OUTT,
// por lo que no se infieren latches.
// ============================================================
module ALU (
    input      [3:0] A,
    input      [3:0] B,
    input      [1:0] OP,
    output reg [3:0] OUTT
);

    localparam [1:0] SUM_OP = 2'b00;
    localparam [1:0] RES_OP = 2'b01;
    localparam [1:0] AND_OP = 2'b10;
    localparam [1:0] OR_OP  = 2'b11;

    always @(*) begin
        case (OP)
            SUM_OP:  OUTT = A + B;
            RES_OP:  OUTT = A - B;
            AND_OP:  OUTT = A & B;
            OR_OP:   OUTT = A | B;
            default: OUTT = 4'b0000;
        endcase
    end

endmodule
