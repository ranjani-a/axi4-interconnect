module axi_addr_decode #(
    parameter int ADDR_WIDTH = 32,
    parameter int NUM_SLAVES = 4,
    parameter int SLV_ID_MSB = 31, // 31:30 is for slave selection as its rep by 2 bits
    parameter int SLV_ID_LSB = 30
)(
    input  logic [ADDR_WIDTH-1:0]addr,
    output logic [$clog2(NUM_SLAVES)-1:0]slv_idx,
    output logic hit //high if the address is mapped to a slave
);

    localparam int SEL_W = SLV_ID_MSB - SLV_ID_LSB + 1;
    logic [SEL_W-1:0] map_val;

    always_comb begin
        map_val = addr[SLV_ID_MSB:SLV_ID_LSB];
        hit = (map_val < NUM_SLAVES);
        slv_idx = hit ? map_val[$clog2(NUM_SLAVES)-1:0] : '0; //slave index selecting the slave number
    end

endmodule 

//this module specifies the number of slaves and confirms whether the slave is mapped to the address or not. It also provides the slave index for the given address.
//address


