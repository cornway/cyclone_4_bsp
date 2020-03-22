
interface sdram_iface_t;
	wire[15:0] Dq;
	logic[11:0] Addr;
	logic[1:0] Ba;
	logic Clk;
	logic Cke;
	logic Cs_n;
	logic Ras_n;
	logic Cas_n;
	logic We_n;
	logic[1:0] Dqm;
endinterface

interface sdram_iface_host_t;
	logic[31:0] wr_addr;
    logic[15:0] wr_data;
    logic wr_enable;

    logic[31:0] rd_addr;
    logic[15:0] rd_data;
    logic rd_ready;
    logic rd_enable;

    logic busy;
    logic rst_n;
    logic clk;
endinterface

module project
#(parameter simulation = 0)
(
    input logic clk_50MHz,

    input logic button_a_i,
    input logic button_b_i,
    input logic button_c_i,
    input logic button_d_i,

    output logic buzz_o,
    output logic led_a_o,
    output logic led_b_o,
    output logic led_c_o,
    output logic led_d_o,

    inout wire[15:0] sd_dq,
    output logic sd_cke,
    output logic sd_clk,
    output logic sd_cs,
    output logic sd_ras,
    output logic sd_cas,
    output logic sd_we,
    output logic sd_ldqm,
    output logic sd_udqm,
    output logic sd_bs0,
    output logic sd_bs1,
    output logic[0:11] sd_sa,

    output logic[7:0] lcd_seg,
    output logic[3:0] lcd_dig,

    output logic[3:0] switch,

    input logic spi2_sck,
    input logic spi2_cs,
    input logic spi2_mosi,
    output logic spi2_miso,

    input logic clk_sim_200MHz,
    input logic clk_sim_4MHz
);

    logic device_ready;
	 logic pll_locked, pll2_locked;

    logic por_reset;

    logic clk_pll_200MHz;
    logic clk_200MHz;

    logic clk_pll_4MHz;
    logic clk_4MHz;

    logic clk_100MHz = '0;
    logic clk_25MHz = '0;

    logic button_a;

    wire reset = por_reset;

    assign clk_200MHz = simulation ? clk_sim_200MHz : clk_pll_200MHz;
    assign clk_4MHz = simulation ? clk_sim_4MHz : clk_pll_4MHz;

    always_ff @(posedge clk_50MHz) clk_25MHz <= ~clk_25MHz;
    always_ff @(posedge clk_200MHz) clk_100MHz <= ~clk_100MHz;

    mod_por por
        (
            .clk_i  (clk_50MHz),
            .rst_o  (por_reset)
         );

    assign device_ready = simulation ? '1 : pll_locked && pll2_locked;

    pll pll_200MHz
        (
            .areset     (por_reset),
            .inclk0     (clk_50MHz),
            .c0         (clk_pll_200MHz),
            .locked     (pll_locked)
        );
    pll2 pll_4MmHz
        (
            .areset     (por_reset),
            .inclk0     (clk_50MHz),
            .c0         (clk_pll_4MHz),
            .locked     (pll2_locked)
        );

    logic buz_trig = '0;
    logic buz_busy;
    assign led_a_o = !buz_busy;

    mod_buzzer
    #(
        .simulation(simulation)
    ) buzzer (
            .clk_4M_i       (clk_4MHz),
            .period_ms_i    (simulation ? 10 : 600),
            .trig_i         (buz_trig),
            .rst_i          (por_reset),
            .cyc_o          (buz_busy),
            .pin_o          (buzz_o)
        );

    mod_button mod_button_a
        (
            .clk_i          (clk_4MHz),
            .pin_i          (button_a_i),
            .pin_o          (button_a)
        );

    always_ff @ (posedge clk_4MHz) begin
        if (!buz_busy) begin
            buz_trig <= button_a;
        end else begin
            buz_trig <= '0;
        end
    end

    sdram_iface_host_t sdram_if_host();

    assign sdram_if_host.clk = clk_100MHz;
    assign sdram_if_host.rst_n = ~reset;
    assign sd_clk = sdram_if_host.clk;

    sdram_controller sdram_uc
        (
            .wr_addr(sdram_if_host.wr_addr),
            .wr_data(sdram_if_host.wr_data),
            .wr_enable(sdram_if_host.wr_enable),
            .rd_addr(sdram_if_host.rd_addr),
            .rd_data(sdram_if_host.rd_data),
            .rd_ready(sdram_if_host.rd_ready),
            .rd_enable(sdram_if_host.rd_enable),

            .busy(sdram_if_host.busy),
            .rst_n(sdram_if_host.rst_n),
            .clk(sdram_if_host.clk),

            /* SDRAM SIDE */
            .addr(sd_sa),
            .bank_addr({sd_bs1, sd_bs0}),
            .data(sd_dq),
            .clock_enable(sd_cke),
            .cs_n(sd_cs),
            .ras_n(sd_ras),
            .cas_n(sd_cas),
            .we_n(sd_we),
            .data_mask_low(sd_ldqm),
            .data_mask_high(sd_udqm)
        );

    spi_phy_if spi2_phy_if();
    spi_host_if spi2_host_if();

    assign spi2_phy_if.sck = spi2_sck;
    assign spi2_phy_if.cs = spi2_cs;
    assign spi2_phy_if.mosi = spi2_mosi;
    assign spi2_miso = spi2_phy_if.miso;

    assign spi2_host_if.clk_i = clk_100MHz;

    spi_16bit_slave spi_16bit_slave_2
        (
            .phy(spi2_phy_if),
            .spi_host(spi2_host_if),

            .conf_cpol('0),
            .conf_dir('0),
            .conf_cpha('0),

            .port_prescaler(5'd4),
            .port_bit_count(4'd16)
        );

    logic[7:0] spi_io_addr;

    logic[31:0] mem_addr = '0;
    logic[15:0] mem_dat;
    logic[15:0] mem_dat_o[2]; 
    logic[1:0] mem_write_delay = '0;

    enum logic[3 : 0]
        {state_idle,
        state_read,
        state_write,
        state_mem_addr_lo,
        state_mem_addr_hi,
        state_mem_dat_lo,
        state_mem_read,
        state_mem_read_ack,
        state_mem_write,
        state_mem_write_ack
        } spi2_state = state_idle,
          spi2_state_next = state_idle,
          spi2_prev_state = state_idle;

    wire[7:0] spi2_ctl = spi2_host_if.dat_i[15:8];
    logic spi2_sm_reset;

    assign spi2_sm_reset = reset;

    always_ff @(posedge clk_50MHz) begin
        if (spi2_sm_reset) begin
            spi2_state <= state_idle;

            sdram_if_host.wr_data <= '0;
            sdram_if_host.wr_addr <= '0;
            sdram_if_host.rd_addr <= '0;
            sdram_if_host.wr_enable <= '0;
            sdram_if_host.rd_enable <= '0;

        end else if (spi2_host_if.wr_req_ack) begin
            case (spi2_state)
                state_idle:
                    case (spi2_ctl)
                        8'h80: begin
                            spi_io_addr <= spi2_host_if.dat_i[7:0];
                            spi2_state <= state_read;
                        end
                        8'hC0: begin
                            spi2_state <= state_mem_addr_lo;
                            spi2_state_next <= state_mem_read;
                        end
                        8'hC1: begin
                            spi2_state <= state_mem_addr_lo;
                            spi2_state_next <= state_mem_dat_lo;
                        end
                        default: begin
                        end
                    endcase
                state_mem_addr_lo: begin
                    mem_addr[15:0] <= spi2_host_if.dat_i;
                    spi2_state <= state_mem_addr_hi;
                end
                state_mem_addr_hi: begin
                    mem_addr[31:16] <= spi2_host_if.dat_i;
                    spi2_state <= spi2_state_next;
                end
                state_mem_dat_lo: begin
                    spi2_state <= state_mem_write;
                    mem_dat <= spi2_host_if.dat_i;
                end
                state_read: begin
                    spi2_state <= state_idle;
                end
                state_write: begin
                    spi2_state <= state_idle;
                end
            endcase
        end else case (spi2_state)
            state_mem_write: begin
                sdram_if_host.wr_addr <= mem_addr;
                sdram_if_host.wr_data <= mem_dat;
                sdram_if_host.wr_enable <= '1;
                mem_write_delay <= 2'd2;
                spi2_state <= state_mem_write_ack;
            end
            state_mem_write_ack: begin
                if (mem_write_delay) begin
                    mem_write_delay <= mem_write_delay - 1'b1;
                end else begin
                    spi2_state <= state_idle;
                end
            end
            state_mem_read: begin
                if (!sdram_if_host.rd_ready) begin
                    sdram_if_host.rd_addr <= mem_addr;
                    sdram_if_host.rd_enable <= '1;
                    spi2_state <= state_mem_read_ack;
                end
            end
            state_mem_read_ack: begin
                if (sdram_if_host.rd_ready) begin
                    mem_dat <= sdram_if_host.rd_data;
                    spi2_state <= state_idle;
                end
            end
        endcase

        spi2_host_if.wr_req_ack <= spi2_host_if.wr_req;
        if (sdram_if_host.rd_enable)
            sdram_if_host.rd_enable <= '0;
        if (sdram_if_host.wr_enable)
            sdram_if_host.wr_enable <= '0;
    end

    always_comb begin
        case (spi_io_addr)
            8'h00:
                spi2_host_if.dat_o = 16'h5555;
            8'h04:
                spi2_host_if.dat_o = mem_dat[7:0];
            8'h05:
                spi2_host_if.dat_o = mem_dat[15:8];
            default:
                spi2_host_if.dat_o = '0;
        endcase
    end

endmodule
