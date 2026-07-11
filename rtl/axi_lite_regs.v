// axi_lite_regs.v
//
// Minimal AXI4-Lite slave exposing 4 x 32-bit read/write registers,
// word-addressed at byte offsets 0x0, 0x4, 0x8, 0xC.
//
// Single-outstanding-transaction slave: AWREADY/WREADY only assert once
// both AWVALID and WVALID are seen together, so a master must hold both
// channels valid until accepted (no independent AW/W acceptance). This
// is the standard simplification used by Xilinx's own AXI4-Lite
// peripheral template and is safe for the PS7 GP master / SmartConnect
// used here.
//
// Ports:
//   s_axi_aclk    - AXI clock (design's single clock domain)
//   s_axi_aresetn - AXI reset, active-low, synchronous
//   s_axi_*       - AXI4-Lite slave interface, Xilinx port naming

module axi_lite_regs #(
    parameter integer C_S_AXI_DATA_WIDTH = 32,
    parameter integer C_S_AXI_ADDR_WIDTH = 4    // 4 x 32-bit regs -> 16 B
) (
    (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 s_axi_aclk CLK" *)
    (* X_INTERFACE_PARAMETER = "ASSOCIATED_BUSIF S_AXI, ASSOCIATED_RESET s_axi_aresetn" *)
    input  wire                              s_axi_aclk,
    (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 s_axi_aresetn RST" *)
    (* X_INTERFACE_PARAMETER = "POLARITY ACTIVE_LOW" *)
    input  wire                              s_axi_aresetn,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_awaddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWPROT" *)
    input  wire [2:0]                        s_axi_awprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWVALID" *)
    input  wire                              s_axi_awvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI AWREADY" *)
    output reg                                s_axi_awready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WDATA" *)
    input  wire [C_S_AXI_DATA_WIDTH-1:0]     s_axi_wdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WSTRB" *)
    input  wire [(C_S_AXI_DATA_WIDTH/8)-1:0] s_axi_wstrb,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WVALID" *)
    input  wire                              s_axi_wvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI WREADY" *)
    output reg                                s_axi_wready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BRESP" *)
    output reg  [1:0]                         s_axi_bresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BVALID" *)
    output reg                                s_axi_bvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI BREADY" *)
    input  wire                              s_axi_bready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARADDR" *)
    input  wire [C_S_AXI_ADDR_WIDTH-1:0]     s_axi_araddr,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARPROT" *)
    input  wire [2:0]                        s_axi_arprot,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARVALID" *)
    input  wire                              s_axi_arvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI ARREADY" *)
    output reg                                s_axi_arready,

    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RDATA" *)
    output reg  [C_S_AXI_DATA_WIDTH-1:0]      s_axi_rdata,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RRESP" *)
    output reg  [1:0]                         s_axi_rresp,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RVALID" *)
    output reg                                s_axi_rvalid,
    (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S_AXI RREADY" *)
    input  wire                              s_axi_rready
);

    localparam integer NUM_REGS      = 4;
    localparam integer REG_SEL_BITS  = 2;  // log2(NUM_REGS)

    reg [C_S_AXI_DATA_WIDTH-1:0] regs [0:NUM_REGS-1];
    integer i;

    wire [REG_SEL_BITS-1:0] waddr_sel = s_axi_awaddr[REG_SEL_BITS+1:2];
    wire [REG_SEL_BITS-1:0] raddr_sel = s_axi_araddr[REG_SEL_BITS+1:2];
    wire write_fire = s_axi_awready && s_axi_awvalid && s_axi_wready && s_axi_wvalid;

    // Write address handshake
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_awready <= 1'b0;
        else
            s_axi_awready <= !s_axi_awready && s_axi_awvalid && s_axi_wvalid;
    end

    // Write data handshake
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_wready <= 1'b0;
        else
            s_axi_wready <= !s_axi_wready && s_axi_awvalid && s_axi_wvalid;
    end

    // Register writes
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            for (i = 0; i < NUM_REGS; i = i + 1)
                regs[i] <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else if (write_fire) begin
            regs[waddr_sel] <= s_axi_wdata;
        end
    end

    // Write response
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_bvalid <= 1'b0;
            s_axi_bresp  <= 2'b00;
        end else if (write_fire) begin
            s_axi_bvalid <= 1'b1;
            s_axi_bresp  <= 2'b00;  // OKAY
        end else if (s_axi_bvalid && s_axi_bready) begin
            s_axi_bvalid <= 1'b0;
        end
    end

    // Read address handshake
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn)
            s_axi_arready <= 1'b0;
        else
            s_axi_arready <= !s_axi_arready && s_axi_arvalid;
    end

    // Read data/response
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_rvalid <= 1'b0;
            s_axi_rresp  <= 2'b00;
            s_axi_rdata  <= {C_S_AXI_DATA_WIDTH{1'b0}};
        end else if (s_axi_arready && s_axi_arvalid && !s_axi_rvalid) begin
            s_axi_rvalid <= 1'b1;
            s_axi_rresp  <= 2'b00;  // OKAY
            s_axi_rdata  <= regs[raddr_sel];
        end else if (s_axi_rvalid && s_axi_rready) begin
            s_axi_rvalid <= 1'b0;
        end
    end

endmodule
