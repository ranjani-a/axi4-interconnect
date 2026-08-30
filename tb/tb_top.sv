module tb_top;

    localparam int NUM_MASTERS = 2;
    localparam int NUM_SLAVES  = 4;
    localparam int ADDR_WIDTH  = 32;
    localparam int DATA_WIDTH  = 32;
    localparam int ID_WIDTH    = 4;
    localparam int STRB_WIDTH  = DATA_WIDTH/8;

    logic clk, rst_n;
    
    // Clock Gen
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // ==========================================
    // FLATTENED ARRAYS (For interconnect)
    // ==========================================
    // Master connections
    logic [NUM_MASTERS*ID_WIDTH-1:0]   m_awid_f;
    logic [NUM_MASTERS*ADDR_WIDTH-1:0] m_awaddr_f;
    logic [NUM_MASTERS*8-1:0]          m_awlen_f;
    logic [NUM_MASTERS*3-1:0]          m_awsize_f;
    logic [NUM_MASTERS*2-1:0]          m_awburst_f;
    logic [NUM_MASTERS-1:0]            m_awvalid;
    logic [NUM_MASTERS-1:0]            m_awready;

    logic [NUM_MASTERS*DATA_WIDTH-1:0] m_wdata_f;
    logic [NUM_MASTERS*STRB_WIDTH-1:0] m_wstrb_f;
    logic [NUM_MASTERS-1:0]            m_wlast;
    logic [NUM_MASTERS-1:0]            m_wvalid;
    logic [NUM_MASTERS-1:0]            m_wready;

    logic [NUM_MASTERS-1:0]            m_bvalid;
    logic [NUM_MASTERS*ID_WIDTH-1:0]   m_bid_f;
    logic [NUM_MASTERS*2-1:0]          m_bresp_f;
    logic [NUM_MASTERS-1:0]            m_bready;

    logic [NUM_MASTERS*ID_WIDTH-1:0]   m_arid_f;
    logic [NUM_MASTERS*ADDR_WIDTH-1:0] m_araddr_f;
    logic [NUM_MASTERS*8-1:0]          m_arlen_f;
    logic [NUM_MASTERS*3-1:0]          m_arsize_f;
    logic [NUM_MASTERS*2-1:0]          m_arburst_f;
    logic [NUM_MASTERS-1:0]            m_arvalid;
    logic [NUM_MASTERS-1:0]            m_arready;

    logic [NUM_MASTERS-1:0]            m_rvalid;
    logic [NUM_MASTERS*DATA_WIDTH-1:0] m_rdata_f;
    logic [NUM_MASTERS*2-1:0]          m_rresp_f;
    logic [NUM_MASTERS-1:0]            m_rlast;
    logic [NUM_MASTERS*ID_WIDTH-1:0]   m_rid_f;
    logic [NUM_MASTERS-1:0]            m_rready;

    // Slave connections
    logic [NUM_SLAVES*ID_WIDTH-1:0]    s_awid_f;
    logic [NUM_SLAVES*ADDR_WIDTH-1:0]  s_awaddr_f;
    logic [NUM_SLAVES*8-1:0]           s_awlen_f;
    logic [NUM_SLAVES*3-1:0]           s_awsize_f;
    logic [NUM_SLAVES*2-1:0]           s_awburst_f;
    logic [NUM_SLAVES-1:0]             s_awvalid;
    logic [NUM_SLAVES-1:0]             s_awready;

    logic [NUM_SLAVES*DATA_WIDTH-1:0]  s_wdata_f;
    logic [NUM_SLAVES*STRB_WIDTH-1:0]  s_wstrb_f;
    logic [NUM_SLAVES-1:0]             s_wlast;
    logic [NUM_SLAVES-1:0]             s_wvalid;
    logic [NUM_SLAVES-1:0]             s_wready;

    logic [NUM_SLAVES*ID_WIDTH-1:0]    s_bid_f;
    logic [NUM_SLAVES*2-1:0]           s_bresp_f;
    logic [NUM_SLAVES-1:0]             s_bvalid;
    logic [NUM_SLAVES-1:0]             s_bready;

    logic [NUM_SLAVES*ID_WIDTH-1:0]    s_arid_f;
    logic [NUM_SLAVES*ADDR_WIDTH-1:0]  s_araddr_f;
    logic [NUM_SLAVES*8-1:0]           s_arlen_f;
    logic [NUM_SLAVES*3-1:0]           s_arsize_f;
    logic [NUM_SLAVES*2-1:0]           s_arburst_f;
    logic [NUM_SLAVES-1:0]             s_arvalid;
    logic [NUM_SLAVES-1:0]             s_arready;

    logic [NUM_SLAVES*ID_WIDTH-1:0]    s_rid_f;
    logic [NUM_SLAVES*DATA_WIDTH-1:0]  s_rdata_f;
    logic [NUM_SLAVES*2-1:0]           s_rresp_f;
    logic [NUM_SLAVES-1:0]             s_rlast;
    logic [NUM_SLAVES-1:0]             s_rvalid;
    logic [NUM_SLAVES-1:0]             s_rready;

    // ==========================================
    // INSTANTIATIONS
    // ==========================================
    genvar m;
    generate
        for (m = 0; m < NUM_MASTERS; m++) begin : gen_mst
            axi_master_vip u_mst (
                .clk(clk), .rst_n(rst_n),
                .m_awid(m_awid_f[m*ID_WIDTH+:ID_WIDTH]), .m_awaddr(m_awaddr_f[m*ADDR_WIDTH+:ADDR_WIDTH]),
                .m_awlen(m_awlen_f[m*8+:8]), .m_awsize(m_awsize_f[m*3+:3]), .m_awburst(m_awburst_f[m*2+:2]),
                .m_awvalid(m_awvalid[m]), .m_awready(m_awready[m]),
                .m_wdata(m_wdata_f[m*DATA_WIDTH+:DATA_WIDTH]), .m_wstrb(m_wstrb_f[m*STRB_WIDTH+:STRB_WIDTH]),
                .m_wlast(m_wlast[m]), .m_wvalid(m_wvalid[m]), .m_wready(m_wready[m]),
                .m_bid(m_bid_f[m*ID_WIDTH+:ID_WIDTH]), .m_bresp(m_bresp_f[m*2+:2]),
                .m_bvalid(m_bvalid[m]), .m_bready(m_bready[m]),
                .m_arid(m_arid_f[m*ID_WIDTH+:ID_WIDTH]), .m_araddr(m_araddr_f[m*ADDR_WIDTH+:ADDR_WIDTH]),
                .m_arlen(m_arlen_f[m*8+:8]), .m_arsize(m_arsize_f[m*3+:3]), .m_arburst(m_arburst_f[m*2+:2]),
                .m_arvalid(m_arvalid[m]), .m_arready(m_arready[m]),
                .m_rid(m_rid_f[m*ID_WIDTH+:ID_WIDTH]), .m_rdata(m_rdata_f[m*DATA_WIDTH+:DATA_WIDTH]),
                .m_rresp(m_rresp_f[m*2+:2]), .m_rlast(m_rlast[m]), .m_rvalid(m_rvalid[m]), .m_rready(m_rready[m])
            );
        end
    endgenerate

    genvar s;
    generate
        for (s = 0; s < NUM_SLAVES; s++) begin : gen_slv
            axi_slave_bram u_slv (
                .clk(clk), .rst_n(rst_n),
                .s_awid(s_awid_f[s*ID_WIDTH+:ID_WIDTH]), .s_awaddr(s_awaddr_f[s*ADDR_WIDTH+:ADDR_WIDTH]),
                .s_awlen(s_awlen_f[s*8+:8]), .s_awsize(s_awsize_f[s*3+:3]), .s_awburst(s_awburst_f[s*2+:2]),
                .s_awvalid(s_awvalid[s]), .s_awready(s_awready[s]),
                .s_wdata(s_wdata_f[s*DATA_WIDTH+:DATA_WIDTH]), .s_wstrb(s_wstrb_f[s*STRB_WIDTH+:STRB_WIDTH]),
                .s_wlast(s_wlast[s]), .s_wvalid(s_wvalid[s]), .s_wready(s_wready[s]),
                .s_bid(s_bid_f[s*ID_WIDTH+:ID_WIDTH]), .s_bresp(s_bresp_f[s*2+:2]),
                .s_bvalid(s_bvalid[s]), .s_bready(s_bready[s]),
                .s_arid(s_arid_f[s*ID_WIDTH+:ID_WIDTH]), .s_araddr(s_araddr_f[s*ADDR_WIDTH+:ADDR_WIDTH]),
                .s_arlen(s_arlen_f[s*8+:8]), .s_arsize(s_arsize_f[s*3+:3]), .s_arburst(s_arburst_f[s*2+:2]),
                .s_arvalid(s_arvalid[s]), .s_arready(s_arready[s]),
                .s_rid(s_rid_f[s*ID_WIDTH+:ID_WIDTH]), .s_rdata(s_rdata_f[s*DATA_WIDTH+:DATA_WIDTH]),
                .s_rresp(s_rresp_f[s*2+:2]), .s_rlast(s_rlast[s]), .s_rvalid(s_rvalid[s]), .s_rready(s_rready[s])
            );
        end
    endgenerate

    axi_interconnect_top #(
        .NUM_MASTERS(NUM_MASTERS), .NUM_SLAVES(NUM_SLAVES),
        .SLV_ID_MSB(31), .SLV_ID_LSB(30) // 0x00..=S0, 0x40..=S1, 0x80..=S2, 0xC0..=S3
    ) dut (
        .clk(clk), .rst_n(rst_n),
        .m_awid_f(m_awid_f), .m_awaddr_f(m_awaddr_f), .m_awlen_f(m_awlen_f), .m_awsize_f(m_awsize_f), .m_awburst_f(m_awburst_f), .m_awvalid(m_awvalid), .m_awready(m_awready),
        .m_wdata_f(m_wdata_f), .m_wstrb_f(m_wstrb_f), .m_wlast(m_wlast), .m_wvalid(m_wvalid), .m_wready(m_wready),
        .m_bvalid(m_bvalid), .m_bid_f(m_bid_f), .m_bresp_f(m_bresp_f), .m_bready(m_bready),
        .m_arid_f(m_arid_f), .m_araddr_f(m_araddr_f), .m_arlen_f(m_arlen_f), .m_arsize_f(m_arsize_f), .m_arburst_f(m_arburst_f), .m_arvalid(m_arvalid), .m_arready(m_arready),
        .m_rvalid(m_rvalid), .m_rdata_f(m_rdata_f), .m_rresp_f(m_rresp_f), .m_rlast(m_rlast), .m_rid_f(m_rid_f), .m_rready(m_rready),
        
        .s_awid_f(s_awid_f), .s_awaddr_f(s_awaddr_f), .s_awlen_f(s_awlen_f), .s_awsize_f(s_awsize_f), .s_awburst_f(s_awburst_f), .s_awvalid(s_awvalid), .s_awready(s_awready),
        .s_wdata_f(s_wdata_f), .s_wstrb_f(s_wstrb_f), .s_wlast(s_wlast), .s_wvalid(s_wvalid), .s_wready(s_wready),
        .s_bid_f(s_bid_f), .s_bresp_f(s_bresp_f), .s_bvalid(s_bvalid), .s_bready(s_bready),
        .s_arid_f(s_arid_f), .s_araddr_f(s_araddr_f), .s_arlen_f(s_arlen_f), .s_arsize_f(s_arsize_f), .s_arburst_f(s_arburst_f), .s_arvalid(s_arvalid), .s_arready(s_arready),
        .s_rid_f(s_rid_f), .s_rdata_f(s_rdata_f), .s_rresp_f(s_rresp_f), .s_rlast(s_rlast), .s_rvalid(s_rvalid), .s_rready(s_rready),
        .aw_grant_pulse(), .aw_grant_idx_f(), .ar_grant_pulse(), .ar_grant_idx_f()
    );

    // ==========================================
    // METRICS TRACKER
    // ==========================================
    int total_cycles = 0;
    int data_beats   = 0;
    always_ff @(posedge clk) begin
        if (rst_n) begin
            total_cycles++;
            if (m_wvalid[0] && m_wready[0]) data_beats++;
            if (m_wvalid[1] && m_wready[1]) data_beats++;
        end
    end

    // ==========================================
    // TEST SEQUENCES
    // ==========================================
    initial begin
        $dumpfile("interconnect.vcd");
        $dumpvars(0, tb_top);
        
        rst_n = 0;
        #20 rst_n = 1;

        $display("--- Starting Tests ---");

        // Test 1: Independent routing (M0 -> S0, M1 -> S1)
        // Since destinations differ, interconnect must route them simultaneously.
        fork
            gen_mst[0].u_mst.write_burst(4'h0, 32'h0000_1000, 3, 32'hAAAA_0000);
            gen_mst[1].u_mst.write_burst(4'h1, 32'h4000_1000, 3, 32'hBBBB_0000);
        join

        // Test 2: Arbitration Contention (M0 -> S2, M1 -> S2)
        // Dest is the same. Arbiter must lock one master, grant it, then serve the other.
        fork
            gen_mst[0].u_mst.write_burst(4'h0, 32'h8000_2000, 7, 32'hCCCC_0000);
            gen_mst[1].u_mst.write_burst(4'h1, 32'h8000_4000, 7, 32'hDDDD_0000);
        join

        // Test 3: Read back to confirm data
        gen_mst[0].u_mst.read_burst(4'h0, 32'h0000_1000, 3);
        
        #100;
        $display("\n--- Simulation Complete ---");
        $display("Total Cycles: %0d", total_cycles);
        $display("Data Beats:   %0d", data_beats);
        
        $finish;
    end

endmodule