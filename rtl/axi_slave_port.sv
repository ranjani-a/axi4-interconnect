// ============================================================================
// axi_slave_port.sv
// The "Gatekeeper" for a single physical slave. 
// It arbitrates incoming requests and locks the channel (via owner_w/owner_r) 
// until the transaction completes, preventing interleaved bursts.
// ============================================================================
module axi_slave_port #(
    parameter int NUM_MASTERS = 2,
    parameter int DATA_WIDTH  = 32,
    parameter int ADDR_WIDTH  = 32,
    parameter int ID_WIDTH    = 4,
    parameter int STRB_WIDTH  = DATA_WIDTH/8
)(
    input  logic clk,
    input  logic rst_n,

    // -- Flattened Master Inputs/Outputs --
    input  logic [NUM_MASTERS*ID_WIDTH-1:0]   m_awid_f,
    input  logic [NUM_MASTERS*ADDR_WIDTH-1:0] m_awaddr_f,
    input  logic [NUM_MASTERS*8-1:0]          m_awlen_f,
    input  logic [NUM_MASTERS*3-1:0]          m_awsize_f,
    input  logic [NUM_MASTERS*2-1:0]          m_awburst_f,
    input  logic [NUM_MASTERS-1:0]            m_awvalid,
    input  logic [NUM_MASTERS-1:0]            aw_req, 
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
    input  logic [NUM_MASTERS-1:0]            ar_req,
    output logic [NUM_MASTERS-1:0]            m_arready,

    output logic [NUM_MASTERS-1:0]            m_rvalid,
    output logic [NUM_MASTERS*DATA_WIDTH-1:0] m_rdata_f,
    output logic [NUM_MASTERS*2-1:0]          m_rresp_f,
    output logic [NUM_MASTERS-1:0]            m_rlast,
    output logic [NUM_MASTERS*ID_WIDTH-1:0]   m_rid_f,
    input  logic [NUM_MASTERS-1:0]            m_rready,

    // -- Physical Slave Interface --
    output logic [ID_WIDTH-1:0]   s_awid,
    output logic [ADDR_WIDTH-1:0] s_awaddr,
    output logic [7:0]            s_awlen,
    output logic [2:0]            s_awsize,
    output logic [1:0]            s_awburst,
    output logic                  s_awvalid,
    input  logic                  s_awready,

    output logic [DATA_WIDTH-1:0] s_wdata,
    output logic [STRB_WIDTH-1:0] s_wstrb,
    output logic                  s_wlast,
    output logic                  s_wvalid,
    input  logic                  s_wready,

    input  logic [ID_WIDTH-1:0]   s_bid,
    input  logic [1:0]            s_bresp,
    input  logic                  s_bvalid,
    output logic                  s_bready,

    output logic [ID_WIDTH-1:0]   s_arid,
    output logic [ADDR_WIDTH-1:0] s_araddr,
    output logic [7:0]            s_arlen,
    output logic [2:0]            s_arsize,
    output logic [1:0]            s_arburst,
    output logic                  s_arvalid,
    input  logic                  s_arready,

    input  logic [ID_WIDTH-1:0]   s_rid,
    input  logic [DATA_WIDTH-1:0] s_rdata,
    input  logic [1:0]            s_rresp,
    input  logic                  s_rlast,
    input  logic                  s_rvalid,
    output logic                  s_rready,

    // -- Debug/Stats --
    output logic                               aw_grant_pulse,
    output logic [$clog2(NUM_MASTERS)-1:0]     aw_grant_idx,
    output logic                               ar_grant_pulse,
    output logic [$clog2(NUM_MASTERS)-1:0]     ar_grant_idx
);
    localparam int M_IDX_W = (NUM_MASTERS > 1) ? $clog2(NUM_MASTERS) : 1;

    // =========================================================================
    // WRITE PATH (AW, W, B)
    // =========================================================================
    typedef enum logic [1:0] {W_IDLE, W_ADDR, W_DATA, W_RESP} w_state_t;
    w_state_t w_state, w_next;
    logic [M_IDX_W-1:0] owner_w;

    logic aw_grant_valid, aw_take;
    
    rr_arbiter #(.NUM_REQ(NUM_MASTERS)) aw_arb (
        .clk(clk), .rst_n(rst_n), .req(aw_req), .take(aw_take),
        .grant(), .grant_valid(aw_grant_valid), .grant_idx(aw_grant_idx)
    );

    assign aw_take = (w_state == W_IDLE) && aw_grant_valid;
    assign aw_grant_pulse = aw_take;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            w_state <= W_IDLE;
            owner_w <= '0;
        end else begin
            w_state <= w_next;
            if (aw_take) owner_w <= aw_grant_idx;
        end
    end

    // Write Path Muxing & FSM
    always_comb begin
        w_next    = w_state;
        m_awready = '0;
        m_wready  = '0;
        m_bvalid  = '0;
        
        // Default Slave Drives
        s_awvalid = 1'b0;
        s_wvalid  = 1'b0;
        s_bready  = 1'b0;

        // Route Data (Defaults to active owner)
        s_awid    = m_awid_f   [owner_w * ID_WIDTH   +: ID_WIDTH];
        s_awaddr  = m_awaddr_f [owner_w * ADDR_WIDTH +: ADDR_WIDTH];
        s_awlen   = m_awlen_f  [owner_w * 8          +: 8];
        s_awsize  = m_awsize_f [owner_w * 3          +: 3];
        s_awburst = m_awburst_f[owner_w * 2          +: 2];

        s_wdata   = m_wdata_f  [owner_w * DATA_WIDTH +: DATA_WIDTH];
        s_wstrb   = m_wstrb_f  [owner_w * STRB_WIDTH +: STRB_WIDTH];
        s_wlast   = m_wlast    [owner_w];

        m_bid_f   = '0; 
        m_bresp_f = '0;

        case (w_state)
            W_IDLE: begin
                if (aw_grant_valid) w_next = W_ADDR;
            end
            W_ADDR: begin
                s_awvalid          = m_awvalid[owner_w];
                m_awready[owner_w] = s_awready;
                if (s_awvalid && s_awready) w_next = W_DATA;
            end
            W_DATA: begin
                s_wvalid          = m_wvalid[owner_w];
                m_wready[owner_w] = s_wready;
                if (s_wvalid && s_wready && s_wlast) w_next = W_RESP;
            end
            W_RESP: begin
                m_bvalid[owner_w] = s_bvalid;
                s_bready          = m_bready[owner_w];
                m_bid_f  [owner_w * ID_WIDTH +: ID_WIDTH] = s_bid;
                m_bresp_f[owner_w * 2        +: 2]        = s_bresp;
                if (s_bvalid && s_bready) w_next = W_IDLE;
            end
        endcase
    end

    // =========================================================================
    // READ PATH (AR, R) - Fully Independent of Write Path
    // =========================================================================
    typedef enum logic [1:0] {R_IDLE, R_ADDR, R_DATA} r_state_t;
    r_state_t r_state, r_next;
    logic [M_IDX_W-1:0] owner_r;

    logic ar_grant_valid, ar_take;

    rr_arbiter #(.NUM_REQ(NUM_MASTERS)) ar_arb (
        .clk(clk), .rst_n(rst_n), .req(ar_req), .take(ar_take),
        .grant(), .grant_valid(ar_grant_valid), .grant_idx(ar_grant_idx)
    );

    assign ar_take = (r_state == R_IDLE) && ar_grant_valid;
    assign ar_grant_pulse = ar_take;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            r_state <= R_IDLE;
            owner_r <= '0;
        end else begin
            r_state <= r_next;
            if (ar_take) owner_r <= ar_grant_idx;
        end
    end

    // Read Path Muxing & FSM
    always_comb begin
        r_next    = r_state;
        m_arready = '0;
        m_rvalid  = '0;
        
        s_arvalid = 1'b0;
        s_rready  = 1'b0;

        s_arid    = m_arid_f   [owner_r * ID_WIDTH   +: ID_WIDTH];
        s_araddr  = m_araddr_f [owner_r * ADDR_WIDTH +: ADDR_WIDTH];
        s_arlen   = m_arlen_f  [owner_r * 8          +: 8];
        s_arsize  = m_arsize_f [owner_r * 3          +: 3];
        s_arburst = m_arburst_f[owner_r * 2          +: 2];

        m_rid_f   = '0;
        m_rdata_f = '0;
        m_rresp_f = '0;
        m_rlast   = '0;

        case (r_state)
            R_IDLE: begin
                if (ar_grant_valid) r_next = R_ADDR;
            end
            R_ADDR: begin
                s_arvalid          = m_arvalid[owner_r];
                m_arready[owner_r] = s_arready;
                if (s_arvalid && s_arready) r_next = R_DATA;
            end
            R_DATA: begin
                m_rvalid[owner_r] = s_rvalid;
                s_rready          = m_rready[owner_r];
                m_rlast [owner_r] = s_rlast;
                
                m_rid_f  [owner_r * ID_WIDTH   +: ID_WIDTH]   = s_rid;
                m_rdata_f[owner_r * DATA_WIDTH +: DATA_WIDTH] = s_rdata;
                m_rresp_f[owner_r * 2          +: 2]          = s_rresp;
                
                if (s_rvalid && s_rready && s_rlast) r_next = R_IDLE;
            end
        endcase
    end

endmodule : axi_slave_port