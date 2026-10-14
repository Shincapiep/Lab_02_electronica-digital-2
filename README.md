# Laboratorio 03: ALU + Banco de Registros

- **Asignatura:** Electrónica Digital II
- **Semestre:** 2026-2

## Integrantes del equipo

- **Samuel Hincapie Perilla**
- **Eduardo Felipe Camacho Lara**
- **Gabriel Alberto Rodríguez Rincón**

---

## Contenido

1. [Descripción del sistema](#1-descripción-del-sistema)
2. [Interfaz de usuario](#2-interfaz-de-usuario)
3. [Arquitectura modular](#3-arquitectura-modular)
4. [Módulos desarrollados](#4-módulos-desarrollados)
5. [Estrategia de visualización](#5-estrategia-de-visualización)
6. [Asignación de pines](#6-asignación-de-pines)
7. [Simulación](#7-simulación)
8. [Implementación y verificación en FPGA](#8-implementación-y-verificación-en-fpga)
9. [Conclusiones](#9-conclusiones)

---

## 1. Descripción del sistema

El sistema implementa en la Zybo Z7 un pequeño datapath formado por un banco de 4 registros de 4 bits (R0–R3), una ALU de 4 bits con 8 operaciones, un selector automático de pares de operandos y un display de 7 segmentos TM1637 que muestra el resultado.

El flujo de uso es:

1. Se elige el registro de destino con BTN0 (el LED RGB indica cuál está seleccionado).
2. Se coloca un valor en los switches y se escribe en ese registro con BTN1.
3. Con BTN2 se recorren los pares de registros que servirán como operandos A y B (los LEDs LD0–LD3 indican cuáles participan).
4. Se coloca el código de operación en `SW[2:0]` y se presiona BTN3: la ALU ejecuta la operación y el resultado se guarda.
5. El display muestra el resultado de la última operación ejecutada y lo conserva hasta la siguiente pulsación de BTN3, aunque cambien los switches, los operandos o el par seleccionado.

---

## 2. Interfaz de usuario

### 2.1 Switches

Los switches cumplen dos funciones en momentos distintos:

| Momento | Switches | Función |
|---|---|---|
| Al presionar **BTN1** | `SW[3:0]` | Dato de 4 bits que se escribe en el registro seleccionado |
| Al presionar **BTN3** | `SW[2:0]` | Código de la operación que ejecuta la ALU |

Como el dato solo se lee al presionar BTN1 y la operación solo al presionar BTN3, compartir los switches no genera conflicto: entre una acción y otra se pueden mover libremente.

### 2.2 Botones

| Botón | Función |
|---|---|
| BTN0 | Selecciona el registro de escritura: R0 → R1 → R2 → R3 → R0 |
| BTN1 | Escribe `SW[3:0]` en el registro seleccionado |
| BTN2 | Avanza al siguiente par de operandos (A, B) |
| BTN3 | Ejecuta la operación `SW[2:0]` y actualiza el resultado del display |

### 2.3 LEDs

Cada LED corresponde a un registro y se enciende si el registro participa en el par de operandos actual:

| Par (A, B) | LD3 | LD2 | LD1 | LD0 |
|---|---|---|---|---|
| (R0, R1) | 0 | 0 | 1 | 1 |
| (R0, R2) | 0 | 1 | 0 | 1 |
| (R0, R3) | 1 | 0 | 0 | 1 |
| (R1, R2) | 0 | 1 | 1 | 0 |
| (R1, R3) | 1 | 0 | 1 | 0 |
| (R2, R3) | 1 | 1 | 0 | 0 |

### 2.4 LED RGB

Indica el registro seleccionado para escritura:

| Registro | Color | R | G | B |
|---|---|---|---|---|
| R0 | Rojo | 1 | 0 | 0 |
| R1 | Verde | 0 | 1 | 0 |
| R2 | Azul | 0 | 0 | 1 |
| R3 | Blanco | 1 | 1 | 1 |

---

## 3. Arquitectura modular

El diseño se dividió en módulos con una sola responsabilidad cada uno. El módulo superior `top.v` no contiene lógica propia: solo declara las señales internas, instancia los módulos y los conecta.

| Módulo | Tipo de lógica | Responsabilidad |
|---|---|---|
| `debounce.v` | Secuencial | Sincroniza cada botón, filtra el rebote y entrega un pulso de un ciclo por pulsación |
| `write_selector.v` | Secuencial + combinacional | Registro de escritura seleccionado (BTN0) y color del LED RGB |
| `comb_selector.v` | Secuencial + combinacional | Índice del par de operandos (BTN2), direcciones de lectura y LEDs |
| `reg_bank.v` | Secuencial | 4 registros de 4 bits, 1 puerto de escritura y 2 de lectura |
| `alu.v` | Combinacional | Las 8 operaciones aritméticas y lógicas |
| `exec_unit.v` | Secuencial + combinacional | Decide qué se escribe en el banco y guarda el resultado ejecutado (BTN3) |
| `display_tm1637.v` | Secuencial | Módulo de visualización; contiene `tm1637_driver.v`, que convierte el resultado y lo envía al display |
| `top.v` | Solo conexiones | Integración con los pines de la tarjeta |

Las señales recorren el sistema en este orden:

1. Los cuatro botones pasan por `debounce` y se convierten en los pulsos `btn0_p` … `btn3_p`.
2. `comb_selector` entrega las direcciones `addr_a` y `addr_b`, con las que `reg_bank` lee los operandos `data_a` y `data_b`.
3. La `alu` opera continuamente sobre `data_a`, `data_b` y `SW[2:0]`.
4. `exec_unit` captura el resultado de la ALU solo cuando llega `btn3_p` y lo pasa a `display_tm1637`.
5. `exec_unit` también controla la escritura del banco: con `btn1_p` escribe los switches, y con `btn3_p` puede escribir el resultado.

Todos los tiempos que dependen del reloj (antirrebote y velocidad del bus del display) son parámetros del `top`. En síntesis se usan los valores reales; en simulación se reducen para que las pruebas duren microsegundos en lugar de segundos.

---

## 4. Módulos desarrollados

### 4.1 `alu.v`: ALU combinacional

Recibe dos operandos de 4 bits y entrega un resultado de **5 bits**. El bit adicional conserva el acarreo de la suma y el signo de la resta, que se perderían con una salida de 4 bits.

| `op` | Operación | Resultado | Rango | Ejemplo (A = 10, B = 5) |
|---|---|---|---|---|
| `000` | ADD | $A + B$ | 0 a 30 | 15 |
| `001` | SUB | $A - B$ (complemento a 2 en 5 bits) | −15 a 15 | 5 |
| `010` | AND | $A \land B$ bit a bit | 0 a 15 | 0 |
| `011` | OR | $A \lor B$ bit a bit | 0 a 15 | 15 |
| `100` | XOR | $A \oplus B$ bit a bit | 0 a 15 | 15 |
| `101` | NOT | $\overline{A}$ | 0 a 15 | 5 |
| `110` | ROL | Rotación de A a la izquierda (el bit 3 pasa al bit 0) | 0 a 15 | 5 |
| `111` | ROR | Rotación de A a la derecha (el bit 0 pasa al bit 3) | 0 a 15 | 5 |

NOT, ROL y ROR solo usan el operando A.

La resta se calcula extendiendo los operandos a 5 bits, por lo que el bit 4 queda como bit de signo. Por ejemplo, $3 - 8 = -5$, que en complemento a 2 de 5 bits es $11011_2 = 27$; el display interpreta ese valor como −5 (sección 5).

El módulo usa `always @(*)`, no tiene reloj ni registros, y todas las ramas del `case` asignan `result`, por lo que no se infieren latches.

### 4.2 `reg_bank.v`: banco de registros

- 4 registros de 4 bits, inicializados en 0.
- Escritura síncrona: en el flanco de subida del reloj, si `write_enable = 1`, se guarda `write_data` en `regs[write_addr]`.
- Dos puertos de lectura combinacionales: `read_data_a = regs[read_addr_a]` y `read_data_b = regs[read_addr_b]`, que entregan los operandos A y B al mismo tiempo.

### 4.3 `comb_selector.v`: selector de operandos

Genera las 6 combinaciones de pares sin repetición de los 4 registros:

$$\binom{4}{2} = \frac{4!}{2!\,2!} = 6$$

Un índice interno `comb_idx` (0 a 5) avanza con cada pulso de BTN2 y vuelve a 0 después del 5. Una tabla convierte el índice en las direcciones `addr_a` y `addr_b`. La salida `active` enciende los dos LEDs de los registros participantes:

```verilog
assign active = (4'b0001 << addr_a) | (4'b0001 << addr_b);
```

En cada par, A siempre es el registro de menor índice. Por eso la resta se calcula como R(menor) − R(mayor); para obtener la resta en el otro sentido basta con intercambiar los valores escritos en los registros.

### 4.4 `debounce.v`: acondicionamiento de botones

Cada botón pasa por tres etapas:

1. Sincronizador de 2 flip-flops, porque los botones son asíncronos respecto al reloj y pueden causar metaestabilidad.
2. Filtro de rebote: un cambio de nivel solo se acepta si se mantiene durante `N_CYCLES` ciclos seguidos; si el botón rebota, el contador se reinicia.
3. Detector de flanco: cuando se confirma la transición de 0 a 1, `btn_pulse` vale 1 durante **un solo ciclo**.

Con el valor por defecto, el tiempo de filtrado es:

$$t_{db} = N_{cycles} \cdot T_{clk} = 250\,000 \cdot 8\ \text{ns} = 2\ \text{ms}$$

El pulso de un ciclo es indispensable para BTN0, BTN2 y BTN3: a 125 MHz, una pulsación de unos 200 ms dura $0.2\ \text{s} / 8\ \text{ns} = 25 \times 10^{6}$ ciclos, y sin el detector de flanco el registro o el índice avanzarían millones de veces.

### 4.5 `write_selector.v`: registro de escritura

Un contador de 2 bits que avanza con cada pulso de BTN0 (R0 → R1 → R2 → R3 → R0) y decodifica el color del LED RGB según la tabla de la sección 2.4.

### 4.6 `exec_unit.v`: escritura y resultado guardado

Cumple dos funciones:

a) Árbitro de escritura del banco

| Evento | `write_enable` | Dirección | Dato |
|---|---|---|---|
| BTN1 | 1 | Registro seleccionado (BTN0) | `SW[3:0]` |
| BTN3 con NOT, ROL o ROR | 1 | Registro A del par actual | Resultado de la ALU |
| BTN3 con ADD, SUB, AND, OR o XOR | 0 | — | — |

Las operaciones de un solo operando se escriben de vuelta en el registro A para que sean **acumulativas**: presionar BTN3 varias veces con ROL sigue rotando el mismo registro, y NOT dos veces devuelve el valor original. Las operaciones de dos operandos no modifican los registros. Como NOT, ROL y ROR siempre producen resultados de 4 bits, el valor escrito cabe en el registro sin pérdida.

b) Registro del resultado

```verilog
always @(posedge clk) begin
    if (exec_pulse) begin
        result_lat <= alu_result;
        op_lat     <= sw[2:0];
    end
end
```

`result_lat` y `op_lat` **solo cambian con el pulso de BTN3**. La ALU calcula continuamente, pero el display recibe estos registros y no la salida de la ALU, así que el valor mostrado se conserva aunque cambien los switches, el par de operandos o el contenido de los registros.

### 4.7 `display_tm1637.v` y `tm1637_driver.v`: display

`display_tm1637` es el módulo de visualización que pide la guía; internamente instancia `tm1637_driver`, que hace dos cosas:

1. Conversión del resultado a los 4 dígitos según la operación.
2. Comunicación con el TM1637 mediante una máquina de estados que genera el protocolo de 2 hilos (CLK y DIO).

El protocolo del TM1637 es parecido a I²C, pero sin dirección de dispositivo y con los datos LSB primero. Cada refresco envía tres transacciones:

| Transacción | Bytes | Significado |
|---|---|---|
| 1 | `0x40` | Modo escritura con autoincremento de dirección |
| 2 | `0xC0`, d3, d2, d1, d0 | Dirección del primer dígito y los 4 patrones de segmentos |
| 3 | `0x8F` | Display encendido, brillo máximo |

Cada transacción comienza con START (DIO baja con CLK en alto) y termina con STOP (DIO sube con CLK en alto). Cada bit se coloca en DIO con CLK en bajo y se lee en el flanco de subida de CLK. Después de cada byte hay un noveno pulso de ACK, durante el cual el driver libera DIO (`tm_dio = 1'bz`).

Con `TM_BIT_HZ` = 10 kHz, el driver avanza un estado cada:

$$t_{tick} = \frac{1}{2 \cdot TM_{bit}} = \frac{1}{2 \cdot 10\ \text{kHz}} = 50\ \mu\text{s}$$

Un bit ocupa 3 estados (150 µs) y una trama completa unos 220 estados (≈ 11 ms). Entre tramas se esperan `REFRESH_TICKS` = 2000 estados (100 ms), así que el display se refresca unas 9 veces por segundo, muy por encima de lo necesario para un valor que solo cambia con BTN3.

---

## 5. Estrategia de visualización

El display tiene 4 dígitos. La representación depende del tipo de operación, para que cada resultado se lea de la forma más natural:

| Operaciones | Representación | Dígito 3 | Dígito 2 | Dígito 1 | Dígito 0 |
|---|---|---|---|---|---|
| ADD, SUB, AND, OR, XOR | Decimal | Signo (`-` o apagado) | Decenas | Unidades | Código de la operación (0 a 4) |
| NOT, ROL, ROR | **Binario** | Bit 3 | Bit 2 | Bit 1 | Bit 0 |

Decimal para las operaciones aritméticas, porque su resultado es un número, y para AND, OR y XOR por consistencia con ellas. El último dígito muestra el código de la operación ejecutada, de modo que se puede saber qué se calculó sin mirar los switches, que pudieron haber cambiado después de presionar BTN3.

Binario para NOT y las rotaciones, porque son operaciones sobre la posición de los bits; en decimal no se notaría que $0101 \to 1010$ es una rotación.

La interpretación del resultado de 5 bits cambia según la operación:

| Operación | Interpretación | Cálculo de la magnitud |
|---|---|---|
| ADD | Sin signo, 5 bits (0 a 30) | El valor tal cual |
| SUB | Con signo, complemento a 2 | Si el bit 4 es 1: signo `-` y magnitud $\overline{r} + 1$ |
| AND, OR, XOR | Sin signo, 4 bits | Bits 3 a 0 |

Por ejemplo, para $3 - 8$ el resultado es $11011_2$. Como el bit 4 es 1, la magnitud es $\overline{11011} + 1 = 00100 + 1 = 00101_2 = 5$, y el display muestra `-051` (signo, 0, 5 y la operación 1).

La conversión a decenas y unidades se hace con una tabla de búsqueda (0 a 30), sin divisiones, para que la síntesis sea sencilla.

## Ejemplos:

| Operación | Resultado guardado | Display |
|---|---|---|
| ADD 10 + 5 | 15 | ` 150` |
| ADD 15 + 15 | 30 | ` 300` |
| SUB 10 − 5 | 5 | ` 051` |
| SUB 3 − 8 | 27 (−5) | `-051` |
| AND 10 & 5 | 0 | ` 002` |
| NOT 1010 | 0101 | `0101` |

---

## 6. Asignación de pines

| Puerto | Pin | Componente |
|---|---|---|
| `clk` | K17 | Reloj de 125 MHz (`create_clock -period 8.00`) |
| `sw[0]` – `sw[3]` | G15, P15, W13, T16 | Switches SW0–SW3 |
| `btn0` – `btn3` | K18, P16, K19, Y16 | Botones BTN0–BTN3 |
| `led[0]` – `led[3]` | M14, M15, G14, D18 | LD0–LD3 (registros activos) |
| `led_r`, `led_g`, `led_b` | V16, F17, M17 | LED RGB LD6 (registro de escritura) |
| `tm_clk` | V12 | Pmod JE, pin 1 → CLK del TM1637 |
| `tm_dio` | W16 | Pmod JE, pin 2 → DIO del TM1637 (con `PULLUP true`) |

El módulo TM1637 se alimenta desde el mismo Pmod JE: VCC en el pin 6 (3.3 V) y GND en el pin 5.

---

## 7. Simulación

Cada módulo se probó por separado y luego se probó el sistema completo con el `top.v` real: comparan cada resultado con el valor esperado e imprimen `PASO` o `FALLO`.

| Testbench | Módulo bajo prueba | Qué verifica |
|---|---|---|
| `tb_alu.v` | `alu` | Las 8 operaciones con las 256 combinaciones de A y B (2058 casos) contra un modelo de referencia |
| `tb_reg_bank.v` | `reg_bank` | Escritura en los 4 registros, lectura por ambos puertos, `write_enable = 0`, sobrescritura y reset |
| `tb_comb_selector.v` | `comb_selector` | Los 6 pares, la vuelta a (R0, R1), los LEDs, que no avance sin pulso y el reset |
| `tb_display_tm1637.v` | `display_tm1637` | Decodifica las tramas del bus TM1637 y compara los 4 dígitos en 9 casos |
| `tb_top.v` | `top` (sistema completo) | Todo el flujo con pulsaciones con rebote: escritura, pares, operaciones, resultado guardado, conservación, LEDs, RGB y dígitos del display |

Para verificar el display sin hardware se escribió `tm1637_monitor.v`, un modelo que observa CLK y DIO, detecta START y STOP, arma los bytes LSB primero y guarda los 4 dígitos de cada trama. Así la simulación comprueba **lo que realmente viaja por el bus**, no solo las señales internas del driver.

En simulación se usan valores reducidos de los parámetros:

| Parámetro | Síntesis | Simulación |
|---|---|---|
| `DEBOUNCE_CYCLES` | 250 000 (2 ms) | 8 |
| `TM_BIT_HZ` | 10 kHz | 6.25 MHz |
| `TM_REFRESH_TICKS` | 2000 | 50 |

Ejecución 
```bash
iverilog -g2005 -o s_alu  tb_alu.v ../src/alu.v
iverilog -g2005 -o s_rb   tb_reg_bank.v ../src/reg_bank.v
iverilog -g2005 -o s_cs   tb_comb_selector.v ../src/comb_selector.v
iverilog -g2005 -o s_disp tb_display_tm1637.v tm1637_monitor.v ../src/display_tm1637.v ../src/tm1637_driver.v
iverilog -g2005 -o s_top  tb_top.v tm1637_monitor.v ../src/top.v ../src/debounce.v ../src/write_selector.v ../src/comb_selector.v ../src/reg_bank.v ../src/alu.v ../src/exec_unit.v ../src/display_tm1637.v ../src/tm1637_driver.v
vvp s_top
gtkwave tb_top.vcd
```

### 7.1 ALU

```
a=10 b= 5 op=000 -> result=01111 (15)
a=10 b= 5 op=001 -> result=00101 (5)
a=10 b= 5 op=010 -> result=00000 (0)
a=10 b= 5 op=011 -> result=01111 (15)
a=10 b= 5 op=100 -> result=01111 (15)
a=10 b= 5 op=101 -> result=00101 (5)
a=10 b= 5 op=110 -> result=00101 (5)
a=10 b= 5 op=111 -> result=00101 (5)
a= 3 b= 8 op=000 -> result=01011 (11)
a= 3 b= 8 op=001 -> result=11011 (27)
--------------------------------------------
ALU: PASO - 2058 casos
```

![Simulación de la ALU](sim/tb_alu.png)

> _[Captura de GTKWave: `a`, `b`, `op` y `result`, primeros 100 ns]_

Con A y B fijos, `result` cambia en el mismo instante que `op`, lo que confirma que la ALU es combinacional. En el caso $3 - 8$ aparece $11011_2$, el −5 en complemento a 2 de 5 bits.

### 7.2 Banco de registros

```
Escritura R0..R3 = A, 5, 3, F verificada
write_enable = 0 no modifica los registros
Sobrescritura de R2 verificada
Reset verificado
--------------------------------------------
REG_BANK: PASO
```

![Simulación del banco de registros](sim/tb_reg_bank.png)

> _[Captura de GTKWave: `clk`, `we`, `waddr`, `wdata`, `ra`, `rb`, `da`, `db`]_

### 7.3 Selector de combinaciones

```
OK idx=0: (R0, R1)  LEDs=0011
OK idx=1: (R0, R2)  LEDs=0101
OK idx=2: (R0, R3)  LEDs=1001
OK idx=3: (R1, R2)  LEDs=0110
OK idx=4: (R1, R3)  LEDs=1010
OK idx=5: (R2, R3)  LEDs=1100
OK idx=0: (R0, R1)  LEDs=0011
...
COMB_SELECTOR: PASO
```

![Simulación del selector](sim/tb_comb_selector.png)

> _[Captura de GTKWave: `next`, `idx`, `aa`, `ab`, `active`]_

### 7.4 Display

| Entrada | Bytes recibidos (d3 d2 d1 d0) | Display |
|---|---|---|
| ADD, 15 | `00 06 6D 3F` | ` 150` |
| ADD, 30 | `00 4F 3F 3F` | ` 300` |
| SUB, +5 | `00 3F 6D 06` | ` 051` |
| SUB, −5 | `40 3F 6D 06` | `-051` |
| SUB, −15 | `40 06 6D 06` | `-151` |
| AND, 0 | `00 3F 3F 5B` | ` 002` |
| XOR, 15 | `00 06 6D 66` | ` 154` |
| NOT, 0101 | `3F 06 3F 06` | `0101` |
| ROL, 1010 | `06 3F 06 3F` | `1010` |

`DISPLAY: PASO`. `0x40` es el segmento central (signo `-`), `0x00` es un dígito apagado y los demás son los patrones de 0 a 9.

![Trama del TM1637](sim/tb_display_tm1637.png)

> _[Captura de GTKWave con zoom en una trama: `tm_clk`, `tm_dio`, `state`, `cur_byte`]_

### 7.5 Sistema completo

| Prueba | Qué se hizo | Resultado |
|---|---|---|
| T1 | Escribir R0 = 10, R1 = 5, R2 = 3, R3 = 2 | Registros correctos |
| T2 | Recorrer los 6 pares con BTN2 y volver al inicio | LEDs correctos en los 7 pasos |
| T3 | ADD, SUB, AND, OR, XOR con R0 = 10, R1 = 5 | 15, 5, 0, 15, 15; R0 no cambia; display ` 150` |
| T4 | NOT, ROL, ROR sobre R0 | 5, 10, 5; R0 se actualiza (acumulativo) |
| T5 | 15 + 15 y 3 − 8 | 30 (` 300`) y 27 (`-051`) |
| T6 | Sin BTN3: mover switches, cambiar el par, escribir un registro y cambiar el registro de escritura | `result_lat` sigue en 27, `op_lat` en 1 y el display en `-051` |
| T6 | Presionar BTN3 con ADD sobre (R0, R2) = (3, 9) | 12, display ` 120` |
| T7 | Recorrer R0–R3 con BTN0 | Rojo, verde, azul, blanco |

```
=============================================
  SISTEMA COMPLETO: PASO 
=============================================
```

Todas las pulsaciones del testbench incluyen 3 rebotes al presionar y 3 al soltar, más cortos que `DEBOUNCE_CYCLES`. Que el registro de escritura y el índice de pares avancen exactamente un paso por pulsación confirma que el antirrebote funciona.

![Simulación del sistema completo](sim/tb_top_general.png)

> _[Captura de GTKWave, vista general: `btn0`–`btn3`, `sw`, `dut.u_comb.comb_idx`, `led`, `dut.u_exec.result_lat`, `dut.u_exec.op_lat`]_

![Conservación del resultado](sim/tb_top_conservacion.png)

> _[Captura de GTKWave con zoom en T6: `btn1`, `btn2`, `btn3`, `sw`, `dut.data_a`, `dut.data_b`, `dut.alu_result`, `dut.u_exec.result_lat`]_

En la prueba T6 se observa que `alu_result` cambia cada vez que cambian los operandos o los switches, mientras que `result_lat` permanece fijo hasta el pulso de BTN3.

---

## 8. Implementación y verificación en FPGA

---

## 9. Conclusiones
