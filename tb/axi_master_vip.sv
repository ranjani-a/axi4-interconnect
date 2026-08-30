module axi_master_vip #(
    parameter int DATA_WIDTH = 32,
    parameter int ADDR_WIDTH = 32,
    parameter int ID_WIDTH   = 4
)(
    input  logic clk,
    input  logic rst_n,

    // AXI Master Ports (Scalar, to be packed in top-level)
    output logic [ID_WIDTH-1:0]   m_awid,
    output logic [ADDR_WIDTH-1:0] m_awaddr,
    output logic [7:0]            m_awlen,
    output logic [2:0]            m_awsize,
    output logic [1:0]            m_awburst,
    output logic                  m_awvalid,
    input  logic                  m_awready,

    output logic [DATA_WIDTH-1:0] m_wdata,
    output logic [(DATA_WIDTH/8)-1:0] m_wstrb,
    output logic                  m_wlast,
    output logic                  m_wvalid,
    input  logic                  m_wready,

    input  logic [ID_WIDTH-1:0]   m_bid,
    input  logic [1:0]            m_bresp,
    input  logic                  m_bvalid,
    output logic                  m_bready,

    output logic [ID_WIDTH-1:0]   m_arid,
    output logic [ADDR_WIDTH-1:0] m_araddr,
    output logic [7:0]            m_arlen,
    output logic [2:0]            m_arsize,
    output logic [1:0]            m_arburst,
    output logic                  m_arvalid,
    input  logic                  m_arready,

    input  logic [ID_WIDTH-1:0]   m_rid,
    input  logic [DATA_WIDTH-1:0] m_rdata,
    input  logic [1:0]            m_rresp,
    input  logic                  m_rlast,
    input  logic                  m_rvalid,
    output logic                  m_rready
);

    import axi_pkg::*;

    initial begin
        m_awvalid = 0; m_wvalid  = 0; m_bready  = 0;
        m_arvalid = 0; m_rready  = 0;
    end

    // =================================================================
    // WRITE BURST TASK
    // =================================================================
    task write_burst(input logic [ID_WIDTH-1:0] id, input logic [ADDR_WIDTH-1:0] addr, input logic [7:0] len, input logic [DATA_WIDTH-1:0] start_data);
        // 1. Address Phase
        m_awid    <= id;
        m_awaddr  <= addr;
        m_awlen   <= len;
        m_awsize  <= 3'b010; // 4 bytes
        m_awburst <= BURST_INCR;
        m_awvalid <= 1'b1;
        
        wait(m_awready === 1'b1);
        @(posedge clk);
        m_awvalid <= 1'b0;

        // 2. Data Phase
        for (int i = 0; i <= len; i++) begin
            m_wdata  <= start_data + i;
            m_wstrb  <= 4'hF;
            m_wlast  <= (i == len);
            m_wvalid <= 1'b1;
            
            wait(m_wready === 1'b1);
            @(posedge clk);
        end
        m_wvalid <= 1'b0;
        m_wlast  <= 1'b0;

        // 3. Response Phase
        m_bready <= 1'b1;
        wait(m_bvalid === 1'b1);
        @(posedge clk);
        m_bready <= 1'b0;
    endtask

    // =================================================================
    // READ BURST TASK
    // =================================================================
    task read_burst(input logic [ID_WIDTH-1:0] id, input logic [ADDR_WIDTH-1:0] addr, input logic [7:0] len);
        // 1. Address Phase
        m_arid    <= id;
        m_araddr  <= addr;
        m_arlen   <= len;
        m_arsize  <= 3'b010; // 4 bytes
        m_arburst <= BURST_INCR;
        m_arvalid <= 1'b1;

        wait(m_arready === 1'b1);
        @(posedge clk);
        m_arvalid <= 1'b0;

        // 2. Data Phase
        m_rready <= 1'b1;
        for (int i = 0; i <= len; i++) begin
            wait(m_rvalid === 1'b1);
            @(posedge clk);
        end
        m_rready <= 1'b0;
    endtask

endmodule