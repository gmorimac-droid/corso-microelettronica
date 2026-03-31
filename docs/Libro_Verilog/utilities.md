
## UTILITIES

<div style="font-size: 0.8em">

# GENERATORE CLOCK CON DUTY-CYCLE

```verilog
//generate clock pulses of 20% duty cycle
module clk_gen (clk);
output clk;
reg clk;
initial
	begin
		#0 clk = 0;
		#5 clk = 1;
		#5 clk = 0;
		#20 clk = 1;
		#5 clk = 0;
		#20 clk = 1;
		#5 clk = 0;
		#10 $stop;
	end
endmodule
```
---

# CONVERTITORE BINARY TO GRAY CODE

```verilog
//binary-to-gray code converter
module bin_to_gray (x1, x2, x3, x4, z1, z2, z3, z4);
input x1, x2, x3, x4;
output z1, z2, z3, z4;
buf inst1 (z1, x1);
xor inst2 (z2, x1, x2);
xor inst3 (z3, x2, x3);
xor inst4 (z4, x3, x4);
endmodule
```

---

# FULL HADDER

```verilog
//full adder using built-in primitives
module full_adder_bip (a, b, cin, sum, cout);
input a, b, cin;
output sum, cout;
xor inst1 (net1, a, b);
and inst2 (net2, a, b);
xor inst3 (sum, net1, cin);
and inst4 (net4, net1, cin);
or inst5 (cout, net4, net2);
endmodule
```

```verilog
//dataflow full adder
module full_adder (a, b, cin, sum, cout);
//list all inputs and outputs
input a, b, cin;
output sum, cout;
//define wires
wire a, b, cin;
wire sum, cout;
//continuous assign
assign sum = (a ^ b) ^ cin;
assign cout = cin & (a ^ b) | (a & b);
endmodule
```

# TESTBENCH FULL HADDER

```verilog
//test bench for full adder using built-in primitives
module full_adder_bip_tb;
reg a, b, cin;
wire sum, cout;
//apply input vectors
initial
	begin: apply_stimulus
		reg[3:0] invect; //invect[3] terminates the for loop
		for (invect = 0; invect < 8; invect = invect + 1)
			begin
				{a, b, cin} = invect [3:0];
				#10 $display ("abcin = %b, cout = %b, sum = %b",
				{a, b, cin}, cout, sum);
			end
	end
//instantiate the module into the test bench
full_adder_bip inst1 (
.a(a),
.b(b),
.cin(cin),
.sum(sum),
.cout(cout)
);
endmodule
```

---

# MULTIPLEXER

```verilog
//dataflow for 4:1 mux using the conditional operator
module mux_4to1_cond2 (s0, s1, d0, d1, d2, d3, z1);
//define inputs and output
input s0, s1, d0, d1, d2, d3;
output z1;
//use the nested conditional operator
assign z1 = s1 ? (s0 ? d3 : d2) : (s0 ? d1 : d0);
endmodule
```

```verilog
//8:1 multiplexed using the case statement
module mux_8to1_case4 (sel, data, z1);
//define inputs and outputs
input [2:0] sel;
input [7:0] data;
output z1;
//variables in always are declared as reg
reg z1;
always @ (sel or data)
begin
case (sel)
	(0) : z1 = data [0];
	(1) : z1 = data [1];
	(2) : z1 = data [2];
	(3) : z1 = data [3];
	(4) : z1 = data [4];
	(5) : z1 = data [5];
	(6) : z1 = data [6];
	(7) : z1 = data [7];
	default : z1 = 1'b0;
endcase
end
endmodule
```
---

# PROM

```verilog
//structural prom to generate four equations
//z1 = x1' x2' + x1 x2'
//z2 = x1' x2' + x1' x2
//z3 = x1' x2 + x1 x2'
module prom3 (x1, x2, z1, z2, z3);
input x1, x2; //define inputs and outputs
output z1, z2, z3;
//define internal nets
wire net1, net2, net3, net4, net5, net6, net7, net8;
//define the input logic
buf (net1, x1);
not (net2, x1);
buf (net3, x2);
not (net4, x2);
//define the logic for the and array
and (net5, net2, net4),
	(net6, net2, net3),
	(net7, net1, net4),
	(net8, net1, net3);
//define the logic for the or array
or  (z1, net5, net7),
	(z2, net5, net6),
	(z3, net6, net7);
endmodule
```

```verilog
//test bench for the structural prom3 module
module prom3_tb;
//inputs are reg for test bench
//outputs are wire for test bench
reg x1, x2;
wire z1, z2, z3;
//display variables
initial
$monitor ("x1 x2 = %b, z1 z2 z3 = %b",
		{x1, x2}, {z1, z2, z3});
//apply input vectors
initial
	begin
		#0 x1 = 1'b0;x2 = 1'b0;
		#10 x1 = 1'b0;x2 = 1'b1;
		#10 x1 = 1'b1;x2 = 1'b0;
		#10 x1 = 1'b1;x2 = 1'b1;
		#10 $stop;
	end
//instantiate the module into the test bench
prom3 inst1 (x1, x2, z1, z2, z3);
endmodule
```

---

# PAL

```verilog
//structural pla to implement four equations
//z1 = x1x2' + x1'x2
//z2 = x1x3 + x1'x3'
//z3 = x1x2' + x1'x2'x3' + x1x3'
//z4 = x1x2x3 + x1'x3
module pla_4eqtns (x1, x2, x3, z1, z2, z3, z4);
//define inputs and outputs
input x1, x2, x3;
output z1, z2, z3, z4;
//define internal nets
wire net1, net2, net3, net4, net5, net6, net7, net8,
	net9, net10, net11, net12, net13, net14;
//design the input drivers
buf (net1, x1);
not (net2, x1);
buf (net3, x2);
not (net4, x2);
buf (net5, x3);
not (net6, x3);
//design the logic for the and array and the or array for z1
and (net7, net1, net4),
	(net8, net2, net3);
or (z1, net7, net8);
//design the logic for the and array and the or array for z2
and (net9, net1, net5),
	(net10, net2, net6);
or (z2, net9, net10);
//design the logic for the and array and the or array for z3
and (net12, net2, net4, net6),
	(net14, net1, net6);
or (z3, net7, net12, net14);
//design the logic for the and array and the or array for z4
and (net11, net1, net3, net5),
	(net13, net2, net5);
or (z4, net11, net13);
endmodule
```
```verilog
//test bench to implement four equations
module pla_4eqtns_tb;
//inputs are reg for test bench
//outputs are wire for test bench
reg x1, x2, x3;
wire z1, z2, z3, z4;
initial //display variables
$monitor ("x1 x2 x3 = %b, z1 z2 z3 z4 = %b", {x1, x2, x3},
		{z1, z2, z3, z4});
initial //apply input vectors
begin
	#0 x1 = 1'b0; x2 = 1'b0; x3 = 1'b0;
	#10 x1 = 1'b0; x2 = 1'b0; x3 = 1'b1;
	#10 x1 = 1'b0; x2 = 1'b1; x3 = 1'b0;
	#10 x1 = 1'b0; x2 = 1'b1; x3 = 1'b1;
	#10 x1 = 1'b1; x2 = 1'b0; x3 = 1'b0;
	#10 x1 = 1'b1; x2 = 1'b0; x3 = 1'b1;
	#10 x1 = 1'b1; x2 = 1'b1; x3 = 1'b0;
	#10 x1 = 1'b1; x2 = 1'b1; x3 = 1'b1;
	#10 $stop;
end
//instantiate the module into the test bench
pla_4eqtns inst1 (x1, x2, x3, z1, z2, z3, z4);
endmodule
```

---

# PRIMITIVE & TABLE
```verilog
//used-defined primitive for a 2-input OR gate
primitive udp_or2 (z1, x1, x2);//list output first
//input/output declarations
input x1, x2;
output z1; //must be output (not reg)
//...for combinational logic
//state table definition
table
//inputs are in same order as input list
// x1 x2 : z1; comment is for readability
	0 0 : 0;
	0 1 : 1;
	1 0 : 1;
	1 1 : 1;
	x 1 : 1;
	1 x : 1;
endtable
endprimitive
```

```verilog
//4:1 multiplexer as a UDP
primitive udp_mux4 (out, s1, s0, d0, d1, d2, d3);
input s1, s0, d0, d1, d2, d3;
output out;
table //define state table
//inputs are in the same order as the input list
// s1 s0 d0 d1 d2 d3 : out comment is for readability
	0 0 1 ? ? ? : 1; //? is "don't care"
	0 0 0 ? ? ? : 0;
	0 1 ? 1 ? ? : 1;
	0 1 ? 0 ? ? : 0;
	1 0 ? ? 1 ? : 1;
	1 0 ? ? 0 ? : 0;
	1 1 ? ? ? 1 : 1;
	1 1 ? ? ? 0 : 0;
	? ? 0 0 0 0 : 0;
	? ? 1 1 1 1 : 1;
endtable
endprimitive
```
