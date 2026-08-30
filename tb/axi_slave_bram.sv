module axi_slave_bram #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ID_WIDTH   = 4,
    parameter int MEM_SIZE   = 4096
)(
    input  logic clk,
    input  logic rst_n,

    // AXI Slave Ports
    input  logic [ID_WIDTH-1:0]   s_awid,
    input  logic [ADDR_WIDTH-1:0] s_awaddr,
    input  logic [7:0]            s_awlen,
    input  logic [2:0]            s_awsize,
    input  logic [1:0]            s_awburst,
    input  logic                  s_awvalid,
    output logic                  s_awready,

    input  logic [DATA_WIDTH-1:0] s_wdata,
    input  logic [(DATA_WIDTH/8)-1:0] s_wstrb,
    input  logic                  s_wlast,
    input  logic                  s_wvalid,
    output logic                  s_wready,

    output logic [ID_WIDTH-1:0]   s_bid,
    output logic [1:0]            s_bresp,
    output logic                  s_bvalid,
    input  logic                  s_bready,

    input  logic [ID_WIDTH-1:0]   s_arid,
    input  logic [ADDR_WIDTH-1:0] s_araddr,
    input  logic [7:0]            s_arlen,
    input  logic [2:0]            s_arsize,
    input  logic [1:0]            s_arburst,
    input  logic                  s_arvalid,
    output logic                  s_arready,

    output logic [ID_WIDTH-1:0]   s_rid,
    output logic [DATA_WIDTH-1:0] s_rdata,
    output logic [1:0]            s_rresp,
    output logic                  s_rlast,
    output logic                  s_rvalid,
    input  logic                  s_rready
);

    import axi_pkg::*;

    // Simple sparse memory (hash map) to simulate a large address space without crashing RAM
    logic [7:0] memory [int]; 

    // --- WRITE FSM ---
    typedef enum logic [1:0] {W_IDLE, W_DATA, W_RESP} w_state_t;
    w_state_t w_state;
    logic [ADDR_WIDTH-1:0] w_addr;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state   <= W_IDLE;
            s_awready <= 1'b0;
            s_wready  <= 1'b0;
            s_bvalid  <= 1'b0;
        end else begin
            case (w_state)
                W_IDLE: begin
                    s_awready <= 1'b1;
                    if (s_awvalid && s_awready) begin
                        w_addr    <= s_awaddr;
                        s_bid     <= s_awid;
                        s_awready <= 1'b0;
                        s_wready  <= 1'b1;
                        w_state   <= W_DATA;
                    end
                end
                W_DATA: begin
                    if (s_wvalid && s_wready) begin
                        // Write bytes based on strobe
                        if (s_wstrb[0]) memory[w_addr]   = s_wdata[7:0];
                        if (s_wstrb[1]) memory[w_addr+1] = s_wdata[15:8];
                        if (s_wstrb[2]) memory[w_addr+2] = s_wdata[23:16];
                        if (s_wstrb[3]) memory[w_addr+3] = s_wdata[31:24];
                        
                        w_addr <= w_addr + 4; // INCR burst
                        
                        if (s_wlast) begin
                            s_wready <= 1'b0;
                            s_bvalid <= 1'b1;
                            s_bresp  <= RESP_OKAY;
                            w_state  <= W_RESP;
                        end
                    end
                end
                W_RESP: begin
                    if (s_bready && s_bvalid) begin
                        s_bvalid <= 1'b0;
                        w_state  <= W_IDLE;
                    end
                end
            endcase
        end
    end

    // --- READ FSM ---
    typedef enum logic [1:0] {R_IDLE, R_DATA} r_state_t;
    r_state_t r_state;
    logic [ADDR_WIDTH-1:0] r_addr;
    logic [7:0] r_beats;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state   <= R_IDLE;
            s_arready <= 1'b0;
            s_rvalid  <= 1'b0;
        end else begin
            case (r_state)
                R_IDLE: begin
                    s_arready <= 1'b1;
                    if (s_arvalid && s_arready) begin
                        r_addr    <= s_araddr;
                        r_beats   <= s_arlen;
                        s_rid     <= s_arid;
                        s_arready <= 1'b0;
                        r_state   <= R_DATA;
                    end
                end
                R_DATA: begin
                    s_rvalid <= 1'b1;
                    s_rresp  <= RESP_OKAY;
                    s_rlast  <= (r_beats == 0);
                    
                    // Default to 0 if uninitialized
                    s_rdata[7:0]   <= memory.exists(r_addr)   ? memory[r_addr]   : 8'h00;
                    s_rdata[15:8]  <= memory.exists(r_addr+1) ? memory[r_addr+1] : 8'h00;
                    s_rdata[23:16] <= memory.exists(r_addr+2) ? memory[r_addr+2] : 8'h00;
                    s_rdata[31:24] <= memory.exists(r_addr+3) ? memory[r_addr+3] : 8'h00;

                    if (s_rvalid && s_rready) begin
                        r_addr <= r_addr + 4;
                        if (s_rlast) begin
                            s_rvalid <= 1'b0;
                            r_state  <= R_IDLE;
                        end else begin
                            r_beats <= r_beats - 1;
                        end
                    end
                end
            endcase
        end
    end

endmodule