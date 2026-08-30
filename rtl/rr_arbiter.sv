// ============================================================================
// rr_arbiter.sv
// A clean, purely synchronous round-robin arbiter. 
// It scans for active requests starting from a rotating priority pointer.
// ============================================================================
module rr_arbiter #(
    parameter int NUM_REQ = 2
)(
    input  logic                       clk,
    input  logic                       rst_n,
    input  logic [NUM_REQ-1:0]         req,
    input  logic                       take,        // High when the granted request is consumed
    output logic [NUM_REQ-1:0]         grant,       // One-hot grant vector
    output logic                       grant_valid, // High if any request is granted
    output logic [$clog2(NUM_REQ)-1:0] grant_idx    // Binary index of the granted request
);

    localparam int PTR_W = (NUM_REQ > 1) ? $clog2(NUM_REQ) : 1;
    logic [PTR_W-1:0] ptr;

    // Combinational arbitration logic
    always_comb begin
        grant       = '0;
        grant_valid = 1'b0;
        grant_idx   = '0;

        // Scan starting from 'ptr' and wrap around
        for (int i = 0; i < NUM_REQ; i++) begin
            int current_idx = (ptr + i) % NUM_REQ;
            if (!grant_valid && req[current_idx]) begin
                grant_valid        = 1'b1;
                grant_idx          = current_idx[PTR_W-1:0];
                grant[current_idx] = 1'b1;
            end
        end
    end

    // Priority pointer update
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ptr <= '0;
        end else if (take && grant_valid) begin
            // Rotate priority to the requester immediately following the winner
            ptr <= (grant_idx + 1'b1) % NUM_REQ;
        end
    end

endmodule : rr_arbiter