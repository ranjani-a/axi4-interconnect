 package axi_pkg;  
    typedef enum logic [1:0] {
        BURST_FIXED = 2'b00,
        BURST_INCR  = 2'b01,
        BURST_WRAP  = 2'b10
    } axi_burst_t;

    typedef enum logic [1:0] {
        RESP_OKAY   = 2'b00,
        RESP_EXOKAY = 2'b01, //response exclusive access okay 
        RESP_SLVERR = 2'b10, // response slave error
        RESP_DECERR = 2'b11 // response decode error (maps to the wrong address)
    } axi_resp_t;

endpackage 