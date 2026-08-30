// ============================================================================
// axi_interconnect_top.sv
// Connects NUM_MASTERS to NUM_SLAVES. 
// Uses distributed arbitration (one arbiter per slave port) and 
// cleanly ORs the individual slave responses back to the master.
// ============================================================================
module axi_interconnect_top #(
    parameter int NUM_MASTERS = 2,
    parameter int NUM_SLAVES  = 4,
    parameter int DATA_WIDTH  = 32,
    parameter int ADDR_WIDTH  = 32,
    parameter int ID_WIDTH    = 4,
    parameter int STRB_WIDTH  = DATA_WIDTH/8,
    parameter int SLV_ID_MSB  = 31,
    parameter int SLV_ID_LSB  = 30
)(
    input  logic clk,
    input  logic rst_n,

    // -- Master Interfaces (Flattened) --
    input  logic [NUM_MASTERS*ID_WIDTH-1:0]   m_awid_f,
    input  logic [NUM_MASTERS*ADDR_WIDTH-1:0] m_awaddr_f,
    input  logic [NUM_MASTERS*8-1:0]          m_awlen_f,
    input  logic [NUM_MASTERS*3-1:0]          m_awsize_f,
    input  logic [NUM_MASTERS*2-1:0]          m_awburst_f,
    input  logic [NUM_MASTERS-1:0]            m_awvalid,
    output logic [NUM_MASTERS-1:0]            m_awready,

    input  logic [NUM_MASTERS*DATA_WIDTH-1:0] m_wdata_f,
    input  logic [NUM_MASTERS*STRB_WIDTH-1:0] m_wstrb_f,
    input  logic [NUM_MASTERS-1:0]            m_wlast,
    input  logic [NUM_MASTERS-1:0]            m_wvalid,
    output logic [NUM_MASTERS-1:0]            m_wready,

    output logic [NUM_MASTERS-1:0]            m_bvalid,
    output logic [NUM_MASTERS*ID_WIDTH-1:0]   m_bid_f,
    output logic [NUM_MASTERS*2-1:0]          m_bresp_f,
    input  logic [NUM_MASTERS-1:0]            m_bready,

    input  logic [NUM_MASTERS*ID_WIDTH-1:0]   m_arid_f,
    input  logic [NUM_MASTERS*ADDR_WIDTH-1:0] m_araddr_f,
    input  logic [NUM_MASTERS*8-1:0]          m_arlen_f,
    input  logic [NUM_MASTERS*3-1:0]          m_arsize_f,
    input  logic [NUM_MASTERS*2-1:0]          m_arburst_f,
    input  logic [NUM_MASTERS-1:0]            m_arvalid,
    output logic [NUM_MASTERS-1:0]            m_arready,

    output logic [NUM_MASTERS-1:0]            m_rvalid,
    output logic [NUM_MASTERS*DATA_WIDTH-1:0] m_rdata_f,
    output logic [NUM_MASTERS*2-1:0]          m_rresp_f,
    output logic [NUM_MASTERS-1:0]            m_rlast,
    output logic [NUM_MASTERS*ID_WIDTH-1:0]   m_rid_f,
    input  logic [NUM_MASTERS-1:0]            m_rready,

    // -- Slave Interfaces (Flattened) --
    output logic [NUM_SLAVES*ID_WIDTH-1:0]    s_awid_f,
    output logic [NUM_SLAVES*ADDR_WIDTH-1:0]  s_awaddr_f,
    output logic [NUM_SLAVES*8-1:0]           s_awlen_f,
    output logic [NUM_SLAVES*3-1:0]           s_awsize_f,
    output logic [NUM_SLAVES*2-1:0]           s_awburst_f,
    output logic [NUM_SLAVES-1:0]             s_awvalid,
    input  logic [NUM_SLAVES-1:0]             s_awready,

    output logic [NUM_SLAVES*DATA_WIDTH-1:0]  s_wdata_f,
    output logic [NUM_SLAVES*STRB_WIDTH-1:0]  s_wstrb_f,
    output logic [NUM_SLAVES-1:0]             s_wlast,
    output logic [NUM_SLAVES-1:0]             s_wvalid,
    input  logic [NUM_SLAVES-1:0]             s_wready,

    input  logic [NUM_SLAVES*ID_WIDTH-1:0]    s_bid_f,
    input  logic [NUM_SLAVES*2-1:0]           s_bresp_f,
    input  logic [NUM_SLAVES-1:0]             s_bvalid,
    output logic [NUM_SLAVES-1:0]             s_bready,

    output logic [NUM_SLAVES*ID_WIDTH-1:0]    s_arid_f,
    output logic [NUM_SLAVES*ADDR_WIDTH-1:0]  s_araddr_f,
    output logic [NUM_SLAVES*8-1:0]           s_arlen_f,
    output logic [NUM_SLAVES*3-1:0]           s_arsize_f,
    output logic [NUM_SLAVES*2-1:0]           s_arburst_f,
    output logic [NUM_SLAVES-1:0]             s_arvalid,
    input  logic [NUM_SLAVES-1:0]             s_arready,

    input  logic [NUM_SLAVES*ID_WIDTH-1:0]    s_rid_f,
    input  logic [NUM_SLAVES*DATA_WIDTH-1:0]  s_rdata_f,
    input  logic [NUM_SLAVES*2-1:0]           s_rresp_f,
    input  logic [NUM_SLAVES-1:0]             s_rlast,
    input  logic [NUM_SLAVES-1:0]             s_rvalid,
    output logic [NUM_SLAVES-1:0]             s_rready,

    // -- Debug/Stats --
    output logic [NUM_SLAVES-1:0]                                aw_grant_pulse,
    output logic [$clog2(NUM_MASTERS)*NUM_SLAVES-1:0]            aw_grant_idx_f,
    output logic [NUM_SLAVES-1:0]                                ar_grant_pulse,
    output logic [$clog2(NUM_MASTERS)*NUM_SLAVES-1:0]            ar_grant_idx_f
);
    localparam int M_IDX_W = (NUM_MASTERS > 1) ? $clog2(NUM_MASTERS) : 1;
    localparam int S_IDX_W = (NUM_SLAVES > 1)  ? $clog2(NUM_SLAVES)  : 1;

    // Decoding Matrices
    logic [S_IDX_W-1:0] aw_tgt_idx [NUM_MASTERS];
    logic               aw_tgt_hit [NUM_MASTERS];
    logic [S_IDX_W-1:0] ar_tgt_idx [NUM_MASTERS];
    logic               ar_tgt_hit [NUM_MASTERS];

    // Master-facing temporary response buses from each slave
    logic [NUM_MASTERS-1:0]            m_awready_mat [NUM_SLAVES];
    logic [NUM_MASTERS-1:0]            m_wready_mat  [NUM_SLAVES];
    logic [NUM_MASTERS-1:0]            m_bvalid_mat  [NUM_SLAVES];
    logic [NUM_MASTERS*ID_WIDTH-1:0]   m_bid_mat     [NUM_SLAVES];
    logic [NUM_MASTERS*2-1:0]          m_bresp_mat   [NUM_SLAVES];

    logic [NUM_MASTERS-1:0]            m_arready_mat [NUM_SLAVES];
    logic [NUM_MASTERS-1:0]            m_rvalid_mat  [NUM_SLAVES];
    logic [NUM_MASTERS*DATA_WIDTH-1:0] m_rdata_mat   [NUM_SLAVES];
    logic [NUM_MASTERS*2-1:0]          m_rresp_mat   [NUM_SLAVES];
    logic [NUM_MASTERS-1:0]            m_rlast_mat   [NUM_SLAVES];
    logic [NUM_MASTERS*ID_WIDTH-1:0]   m_rid_mat     [NUM_SLAVES];

    // 1. Generate Address Decoders for each Master
    genvar m;
    generate
        for (m = 0; m < NUM_MASTERS; m++) begin : gen_decoders
            axi_addr_decode #(
                .ADDR_WIDTH(ADDR_WIDTH), .NUM_SLAVES(NUM_SLAVES), 
                .SLV_ID_MSB(SLV_ID_MSB), .SLV_ID_LSB(SLV_ID_LSB)
            ) u_aw_dec (
                .addr(m_awaddr_f[m*ADDR_WIDTH +: ADDR_WIDTH]), .slv_idx(aw_tgt_idx[m]), .hit(aw_tgt_hit[m])
            );

            axi_addr_decode #(
                .ADDR_WIDTH(ADDR_WIDTH), .NUM_SLAVES(NUM_SLAVES), 
                .SLV_ID_MSB(SLV_ID_MSB), .SLV_ID_LSB(SLV_ID_LSB)
            ) u_ar_dec (
                .addr(m_araddr_f[m*ADDR_WIDTH +: ADDR_WIDTH]), .slv_idx(ar_tgt_idx[m]), .hit(ar_tgt_hit[m])
            );
        end
    endgenerate

    // 2. Generate Slave Ports (Gatekeepers)
    genvar s;
    generate
        for (s = 0; s < NUM_SLAVES; s++) begin : gen_slaves
            
            logic [NUM_MASTERS-1:0] req_aw, req_ar;
            genvar m_req;
            for (m_req = 0; m_req < NUM_MASTERS; m_req++) begin : req_map
                assign req_aw[m_req] = m_awvalid[m_req] && aw_tgt_hit[m_req] && (aw_tgt_idx[m_req] == s[S_IDX_W-1:0]);
                assign req_ar[m_req] = m_arvalid[m_req] && ar_tgt_hit[m_req] && (ar_tgt_idx[m_req] == s[S_IDX_W-1:0]);
            end

            axi_slave_port #(
                .NUM_MASTERS(NUM_MASTERS), .DATA_WIDTH(DATA_WIDTH), 
                .ADDR_WIDTH(ADDR_WIDTH), .ID_WIDTH(ID_WIDTH), .STRB_WIDTH(STRB_WIDTH)
            ) u_port (
                .clk(clk), .rst_n(rst_n),

                // Master-side signals mapped to this slave port
                .m_awid_f(m_awid_f), .m_awaddr_f(m_awaddr_f), .m_awlen_f(m_awlen_f),
                .m_awsize_f(m_awsize_f), .m_awburst_f(m_awburst_f), .m_awvalid(m_awvalid),
                .aw_req(req_aw), .m_awready(m_awready_mat[s]),
                
                .m_wdata_f(m_wdata_f), .m_wstrb_f(m_wstrb_f), .m_wlast(m_wlast),
                .m_wvalid(m_wvalid), .m_wready(m_wready_mat[s]),
                
                .m_bvalid(m_bvalid_mat[s]), .m_bid_f(m_bid_mat[s]), 
                .m_bresp_f(m_bresp_mat[s]), .m_bready(m_bready),

                .m_arid_f(m_arid_f), .m_araddr_f(m_araddr_f), .m_arlen_f(m_arlen_f),
                .m_arsize_f(m_arsize_f), .m_arburst_f(m_arburst_f), .m_arvalid(m_arvalid),
                .ar_req(req_ar), .m_arready(m_arready_mat[s]),
                
                .m_rvalid(m_rvalid_mat[s]), .m_rdata_f(m_rdata_mat[s]), 
                .m_rresp_f(m_rresp_mat[s]), .m_rlast(m_rlast_mat[s]), 
                .m_rid_f(m_rid_mat[s]), .m_rready(m_rready),

                // Physical Slave bus routing out
                .s_awid(s_awid_f[s*ID_WIDTH+:ID_WIDTH]), .s_awaddr(s_awaddr_f[s*ADDR_WIDTH+:ADDR_WIDTH]),
                .s_awlen(s_awlen_f[s*8+:8]), .s_awsize(s_awsize_f[s*3+:3]),
                .s_awburst(s_awburst_f[s*2+:2]), .s_awvalid(s_awvalid[s]), .s_awready(s_awready[s]),
                
                .s_wdata(s_wdata_f[s*DATA_WIDTH+:DATA_WIDTH]), .s_wstrb(s_wstrb_f[s*STRB_WIDTH+:STRB_WIDTH]),
                .s_wlast(s_wlast[s]), .s_wvalid(s_wvalid[s]), .s_wready(s_wready[s]),
                
                .s_bid(s_bid_f[s*ID_WIDTH+:ID_WIDTH]), .s_bresp(s_bresp_f[s*2+:2]),
                .s_bvalid(s_bvalid[s]), .s_bready(s_bready[s]),
                
                .s_arid(s_arid_f[s*ID_WIDTH+:ID_WIDTH]), .s_araddr(s_araddr_f[s*ADDR_WIDTH+:ADDR_WIDTH]),
                .s_arlen(s_arlen_f[s*8+:8]), .s_arsize(s_arsize_f[s*3+:3]),
                .s_arburst(s_arburst_f[s*2+:2]), .s_arvalid(s_arvalid[s]), .s_arready(s_arready[s]),
                
                .s_rid(s_rid_f[s*ID_WIDTH+:ID_WIDTH]), .s_rdata(s_rdata_f[s*DATA_WIDTH+:DATA_WIDTH]),
                .s_rresp(s_rresp_f[s*2+:2]), .s_rlast(s_rlast[s]), .s_rvalid(s_rvalid[s]),
                .s_rready(s_rready[s]),
                
                // Stats
                .aw_grant_pulse(aw_grant_pulse[s]),
                .aw_grant_idx(aw_grant_idx_f[s*M_IDX_W +: M_IDX_W]),
                .ar_grant_pulse(ar_grant_pulse[s]),
                .ar_grant_idx(ar_grant_idx_f[s*M_IDX_W +: M_IDX_W])
            );
        end
    endgenerate

    // 3. OR the inactive buses together to feed the Masters
    // Since only ONE slave port drives a master at any given time, 
    // simply ORing the arrays works perfectly without complex multiplexers.
    always_comb begin
        m_awready = '0; m_wready  = '0;
        m_bvalid  = '0; m_bid_f   = '0; m_bresp_f = '0;
        
        m_arready = '0; m_rvalid  = '0;
        m_rdata_f = '0; m_rresp_f = '0; m_rlast   = '0; m_rid_f   = '0;

        for (int i = 0; i < NUM_SLAVES; i++) begin
            m_awready |= m_awready_mat[i];
            m_wready  |= m_wready_mat[i];
            m_bvalid  |= m_bvalid_mat[i];
            m_bid_f   |= m_bid_mat[i];
            m_bresp_f |= m_bresp_mat[i];
            
            m_arready |= m_arready_mat[i];
            m_rvalid  |= m_rvalid_mat[i];
            m_rdata_f |= m_rdata_mat[i];
            m_rresp_f |= m_rresp_mat[i];
            m_rlast   |= m_rlast_mat[i];
            m_rid_f   |= m_rid_mat[i];
        end
    end

endmodule : axi_interconnect_top