//=======================================================
//  Arcade: Food Fight for MiSTer
//
//                           Written by MiSTer-X 2019
//=======================================================


module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [48:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler
	output        VGA_DISABLE, // analog out is off

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	output	USER_OSD,
	// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: per-pin push-pull mask
	output	[7:0] USER_PP,
	// [MiSTer-DB9 END]
	input	[7:0] USER_IN,
	output	[7:0] USER_OUT,
	input         OSD_STATUS
);


// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: USER_PP default (port_batch replaces with USER_PP_DRIVE)
assign USER_PP = USER_PP_DRIVE;
// [MiSTer-DB9 END]
assign VGA_F1    = 0;
assign VGA_SCALER= 0;
// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper
wire         CLK_JOY = CLK_50M;                 // Assign clock between 40-50Mhz
wire   [1:0] joy_type        = status[127:126]; // 0=Off, 1=Saturn, 2=DB9MD, 3=DB15
wire         joy_2p          = status[125];
wire         joy_db9md_en    = (joy_type == 2'd2);
wire         joy_db15_en     = (joy_type == 2'd3);
wire         joy_any_en      = |joy_type;
// Legacy 3-bit alias for fork-specific MT32 / SNAC fallback code. Non-canonical
// RHS variants (ext_iec_en, mt32_disable) need a hand-port — alias is raw.
wire   [2:0] JOY_FLAG        = {joy_db9md_en, joy_db15_en, joy_2p};
// [MiSTer-DB9 END]

// [MiSTer-DB9-Pro BEGIN] - Saturn key gate
wire         saturn_unlocked;                   // driven by hps_io UIO_DB9_KEY (0xFE)
// [MiSTer-DB9-Pro END]

// [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joydb wrapper wires + instance
wire   [7:0] USER_OUT_DRIVE;
wire   [7:0] USER_PP_DRIVE;
wire  [15:0] joydb_1, joydb_2;
wire         joydb_1ena, joydb_2ena;
wire  [15:0] joy_raw_payload;

joydb joydb (
  .clk             ( CLK_JOY         ),
  .USER_IN         ( USER_IN         ),
  .joy_type        ( joy_type        ),
  .joy_2p          ( joy_2p          ),
  .saturn_unlocked ( saturn_unlocked ),
  .USER_OUT_DRIVE  ( USER_OUT_DRIVE  ),
  .USER_PP_DRIVE   ( USER_PP_DRIVE   ),
  .USER_OSD        ( USER_OSD        ),
  .joydb_1         ( joydb_1         ),
  .joydb_2         ( joydb_2         ),
  .joydb_1ena      ( joydb_1ena      ),
  .joydb_2ena      ( joydb_2ena      ),
  .joy_raw         ( joy_raw_payload )
);

assign USER_OUT = USER_OUT_DRIVE;
// [MiSTer-DB9 END]

assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;

assign {FB_PAL_CLK, FB_FORCE_BLANK, FB_PAL_ADDR, FB_PAL_DOUT, FB_PAL_WR} = '0;

wire [1:0] ar = status[20:19];

assign VIDEO_ARX =  (!ar) ? ( 8'd8) : (ar - 1'd1);
assign VIDEO_ARY =  (!ar) ? ( 8'd7) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.FoodFight;;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
		// [MiSTer-DB9-Pro BEGIN] - Saturn-first joy_type (canonical bit notation)
	"O[127:126],UserIO Joystick,Off,Saturn,DB9MD,DB15;",
	"O[125],UserIO Players, 1 Player,2 Players;",
	// [MiSTer-DB9-Pro END]
	"-;",
	"O8,Control Player 1,Analog,D-Pad;",
	"O9,Control Player 2,Analog,D-Pad;",
	"-;",
	"OA,Self-Test,Off,On;",
	"-;",
	"R0,Reset;",
	"J1,Throw,Start 1P,Start 2P,Coin;",
	"jn,A,Start,Select,R;",
	"V,v",`BUILD_DATE
};

wire bCabinet = 1'b0;

wire bPAna0 = status[8];
wire bPAna1 = status[9];

wire bSelfTst = status[10];


////////////////////   CLOCKS   ///////////////////

wire clk_48M;
wire clk_hdmi = clk_48M;
wire clk_sys = clk_48M;

pll pll
(
	.rst(0),
	.refclk(CLK_50M),
	.outclk_0(clk_48M)
);

///////////////////////////////////////////////////

// [MiSTer-DB9 BEGIN] - widened to 128 bits for joy_type at [127:126] and joy_2p at [125]
wire [127:0] status;
// [MiSTer-DB9 END]
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [15:0] joystk1_USB, joystk2_USB;
wire [15:0] joystick_analog_0;
wire [15:0] joystick_analog_1;
wire [21:0] gamma_bus;

// CO S2 S1 F1 U D L R 
// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open
wire [31:0] joystk1 = joydb_1ena ? (OSD_STATUS ? 32'b0 : {joydb_1[11],joydb_1[9],joydb_1[10],joydb_1[4:0]}) : joystk1_USB;
// [MiSTer-DB9-Pro END]
// [MiSTer-DB9-Pro BEGIN] - DB controllers muted while OSD is open
wire [31:0] joystk2 = joydb_2ena ? (OSD_STATUS ? 32'b0 : {joydb_2[11],joydb_2[10],joydb_2[9],joydb_2[4:0]}) : joydb_1ena ? joystk1_USB : joystk2_USB;
// [MiSTer-DB9-Pro END]




hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

        // [MiSTer-DB9 BEGIN] - DB9/SNAC8 support: joy_raw
        .joy_raw(OSD_STATUS ? joy_raw_payload : 16'b0),
        // [MiSTer-DB9 END]
        // [MiSTer-DB9-Pro BEGIN] - Saturn key gate
        .saturn_unlocked(saturn_unlocked),
        // [MiSTer-DB9-Pro END]

	.buttons(buttons),
	.status(status),
	.status_menumask({direct_video}),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.joystick_0(joystk1_USB),
	.joystick_1(joystk2_USB),
	.joystick_l_analog_0(joystick_analog_0),
	.joystick_l_analog_1(joystick_analog_1)	
);
wire m_down2   = joystk2[2];
wire m_left2   = joystk2[1];
wire m_right2  = joystk2[0];
wire m_trig21  = joystk2[4];
wire m_trig22  = joystk2[4];

wire m_start1  = joystk1[5] | joystk2[5];
wire m_start2  = joystk1[6] | joystk2[6];

wire m_up1     = joystk1[3] | (bCabinet ? 1'b0 : m_up2);
wire m_down1   = joystk1[2] | (bCabinet ? 1'b0 : m_down2);
wire m_left1   = joystk1[1] | (bCabinet ? 1'b0 : m_left2);
wire m_right1  = joystk1[0] | (bCabinet ? 1'b0 : m_right2);
wire m_trig11  = joystk1[4] | (bCabinet ? 1'b0 : m_trig21);
wire m_trig12  = joystk1[4] | (bCabinet ? 1'b0 : m_trig22);

wire m_coin1   = joystk1[7];
wire m_coin2   = joystk2[7];


///////////////////////////////////////////////////

wire hblank, vblank;
wire ce_vid;
wire hs, vs;
wire [3:0] r,g,b;

reg ce_pix;
always @(posedge clk_hdmi) begin
	reg old_clk;
	old_clk <= ce_vid;
	ce_pix  <= old_clk & ~ce_vid;
end


arcade_video #(256,12) arcade_video
(
	.*,

	.clk_video(clk_hdmi),

	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(~hs),
	.VSync(~vs),

	.fx(status[5:3])
);

wire			PCLK;
wire  [8:0] HPOS,VPOS;
wire [11:0] POUT;
HVGEN hvgen
(
	.HPOS(HPOS),.VPOS(VPOS),.PCLK(PCLK),.iRGB(POUT),
	.oRGB({b,g,r}),.HBLK(hblank),.VBLK(vblank),.HSYN(hs),.VSYN(vs)
);
assign ce_vid = PCLK;


wire [7:0] AOUT;
assign AUDIO_L = {AOUT,AOUT};
assign AUDIO_R = AUDIO_L;
assign AUDIO_S = 0; // unsigned PCM


///////////////////////////////////////////////////

wire iRST = RESET | status[0] | buttons[1] | ioctl_download;


wire [7:0] Stk0X = (~joystick_analog_0[ 7:0])+8'd128;
wire [7:0] Stk0Y = (~joystick_analog_0[15:8])+8'd128;
wire [7:0] SStk0X, SStk0Y;
PseudoAnaStk A0(PCLK,VPOS,m_left1,m_right1,m_up1,m_down1,SStk0X,SStk0Y);
wire [7:0] AX0 = bPAna0 ? SStk0X : Stk0X;
wire [7:0] AY0 = bPAna0 ? SStk0Y : Stk0Y;

wire [7:0] Stk1X = (~joystick_analog_1[ 7:0])+8'd128;
wire [7:0] Stk1Y = (~joystick_analog_1[15:8])+8'd128;
wire [7:0] SStk1X, SStk1Y;
PseudoAnaStk A1(PCLK,VPOS,m_left2,m_right2,m_up2,m_down2,SStk1X,SStk1Y);
wire [7:0] AX1 = bPAna1 ? SStk1X : Stk1X;
wire [7:0] AY1 = bPAna1 ? SStk1Y : Stk1Y;

wire [7:0] DIN = ~{bSelfTst,(m_trig22|m_trig21),(m_trig12|m_trig11),1'b0,m_start2,m_start1,1'b0,(m_coin1|m_coin2)};


FPGA_FoodFight GameCore ( 
	.MCLK(clk_48M),.RESET(iRST),

	.AX0(AX0),.AY0(AY0),.AX1(AX1),.AY1(AY1),.DIN(DIN),
	.PH(HPOS),.PV(VPOS),.PCLK(PCLK),.POUT(POUT),
	.SOUT(AOUT),

	.ROMCL(clk_sys),.ROMAD(ioctl_addr),.ROMDT(ioctl_dout),.ROMEN(ioctl_wr)
);

endmodule


module HVGEN
(
	output  [8:0]		HPOS,
	output  [8:0]		VPOS,
	input 				PCLK,
	input	 [11:0]		iRGB,

	output reg [11:0]	oRGB,
	output reg			HBLK = 1,
	output reg			VBLK = 1,
	output reg			HSYN = 1,
	output reg			VSYN = 1
);

reg [8:0] hcnt = 0;
reg [8:0] vcnt = 0;

assign HPOS = hcnt-5'd16;
assign VPOS = vcnt;

always @(posedge PCLK) begin
	case (hcnt)
		 15: begin HBLK <= 0; hcnt <= hcnt+1'd1; end
		272: begin HBLK <= 1; hcnt <= hcnt+1'd1; end
		311: begin HSYN <= 0; hcnt <= hcnt+1'd1; end
		342: begin HSYN <= 1; hcnt <= 471;       end
		511: begin hcnt <= 0;
			case (vcnt)
				223: begin VBLK <= 1; vcnt <= vcnt+1'd1; end
				235: begin VSYN <= 0; vcnt <= vcnt+1'd1; end
				242: begin VSYN <= 1; vcnt <= 492;       end
				511: begin VBLK <= 0; vcnt <= 0;         end
				default: vcnt <= vcnt+1'd1;
			endcase
		end
		default: hcnt <= hcnt+1'd1;
	endcase
	oRGB <= (HBLK|VBLK) ? 12'h0 : iRGB;
end

endmodule


module PseudoAnaStk
(
	input				CLK,
	input	 [8:0]	PV,

	input				LF,
	input				RG,
	input				UP,
	input				DW,

	output [7:0]	AX,
	output [7:0]	AY
);

reg  signed [9:0] StkX = 0, StkY = 0;

wire signed [9:0] DELT = 15;
wire signed [9:0] PLIM = 120;
wire signed [9:0] MLIM = -10'd120;

reg [8:0] pPV;
always @(posedge CLK) begin
	if ((pPV!=PV)&(PV==0)) begin

		if (LF) StkX = StkX+DELT;
		else if (RG) StkX = StkX-DELT;
		else StkX = (StkX>0) ? (StkX-DELT) : (StkX<0) ? (StkX+DELT) : StkX;

		if (UP) StkY = StkY+DELT;
		else if (DW) StkY = StkY-DELT;
		else StkY = (StkY>0) ? (StkY-DELT) : (StkY<0) ? (StkY+DELT) : StkY;

		StkX = (StkX<MLIM) ? MLIM : (StkX>PLIM) ? PLIM : StkX;
		StkY = (StkY<MLIM) ? MLIM : (StkY>PLIM) ? PLIM : StkY;

	end
	pPV <= PV;
end

wire [7:0] oStkX = StkX + 8'd127;
wire [7:0] oStkY = StkY + 8'd127;

assign AX = oStkX;
assign AY = oStkY;

endmodule

