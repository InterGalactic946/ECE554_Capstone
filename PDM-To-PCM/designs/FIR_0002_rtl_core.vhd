-- ------------------------------------------------------------------------- 
-- High Level Design Compiler for Intel(R) FPGAs Version 25.1std (Release Build #1129)
-- Quartus Prime development tool and MATLAB/Simulink Interface
-- 
-- Legal Notice: Copyright 2025 Intel Corporation.  All rights reserved.
-- Your use of  Intel Corporation's design tools,  logic functions and other
-- software and  tools, and its AMPP partner logic functions, and any output
-- files any  of the foregoing (including  device programming  or simulation
-- files), and  any associated  documentation  or information  are expressly
-- subject  to the terms and  conditions of the  Intel FPGA Software License
-- Agreement, Intel MegaCore Function License Agreement, or other applicable
-- license agreement,  including,  without limitation,  that your use is for
-- the  sole  purpose of  programming  logic devices  manufactured by  Intel
-- and  sold by Intel  or its authorized  distributors. Please refer  to the
-- applicable agreement for further details.
-- ---------------------------------------------------------------------------

-- VHDL created from FIR_0002_rtl_core
-- VHDL created on Sat Apr 11 20:07:29 2026


library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.NUMERIC_STD.all;
use IEEE.MATH_REAL.all;
use std.TextIO.all;
use work.dspba_library_package.all;

LIBRARY altera_mf;
USE altera_mf.altera_mf_components.all;
LIBRARY altera_lnsim;
USE altera_lnsim.altera_lnsim_components.altera_syncram;
LIBRARY lpm;
USE lpm.lpm_components.all;

entity FIR_0002_rtl_core is
    port (
        xIn_v : in std_logic_vector(0 downto 0);  -- sfix1
        xIn_c : in std_logic_vector(7 downto 0);  -- sfix8
        xIn_0 : in std_logic_vector(17 downto 0);  -- sfix18
        bankIn_0 : in std_logic_vector(1 downto 0);  -- sfix2
        xIn_mode : in std_logic_vector(1 downto 0);  -- sfix2
        enable_i : in std_logic_vector(0 downto 0);  -- sfix1
        xOut_v : out std_logic_vector(0 downto 0);  -- ufix1
        xOut_c : out std_logic_vector(7 downto 0);  -- ufix8
        xOut_0 : out std_logic_vector(40 downto 0);  -- sfix41
        clk : in std_logic;
        areset : in std_logic
    );
end FIR_0002_rtl_core;

architecture normal of FIR_0002_rtl_core is

    attribute altera_attribute : string;
    attribute altera_attribute of normal : architecture is "-name AUTO_SHIFT_REGISTER_RECOGNITION OFF; -name PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION ON; -name MESSAGE_DISABLE 10036; -name MESSAGE_DISABLE 10037; -name MESSAGE_DISABLE 14130; -name MESSAGE_DISABLE 14320; -name MESSAGE_DISABLE 15400; -name MESSAGE_DISABLE 14130; -name MESSAGE_DISABLE 10036; -name MESSAGE_DISABLE 12020; -name MESSAGE_DISABLE 12030; -name MESSAGE_DISABLE 12010; -name MESSAGE_DISABLE 12110; -name MESSAGE_DISABLE 14320; -name MESSAGE_DISABLE 13410; -name MESSAGE_DISABLE 113007";
    
    signal GND_q : STD_LOGIC_VECTOR (0 downto 0);
    signal VCC_q : STD_LOGIC_VECTOR (0 downto 0);
    signal d_xIn_xIn_mode_12_q : STD_LOGIC_VECTOR (1 downto 0);
    signal d_xIn_bankIn_0_12_q : STD_LOGIC_VECTOR (1 downto 0);
    signal d_xIn_0_12_q : STD_LOGIC_VECTOR (17 downto 0);
    signal d_in0_m0_wi0_wo0_assign_id1_q_12_q : STD_LOGIC_VECTOR (0 downto 0);
    signal d_in0_m0_wi0_wo0_assign_id1_q_13_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_run_count : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_run_preEnaQ : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_run_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_run_out : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_run_enableQ : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_run_ctrl : STD_LOGIC_VECTOR (2 downto 0);
    signal u0_m0_wo0_memread_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_compute_q : STD_LOGIC_VECTOR (0 downto 0);
    signal d_u0_m0_wo0_compute_q_15_q : STD_LOGIC_VECTOR (0 downto 0);
    signal d_u0_m0_wo0_compute_q_16_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_mode_q : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_count0_inner_q : STD_LOGIC_VECTOR (7 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_count0_inner_i : SIGNED (7 downto 0);
    attribute preserve : boolean;
    attribute preserve of u0_m0_wo0_wi0_r0_ra0_count0_inner_i : signal is true;
    signal u0_m0_wo0_wi0_r0_ra0_count0_q : STD_LOGIC_VECTOR (7 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_count0_i : UNSIGNED (6 downto 0);
    attribute preserve of u0_m0_wo0_wi0_r0_ra0_count0_i : signal is true;
    signal u0_m0_wo0_wi0_r0_ra0_count1_lutreg_q : STD_LOGIC_VECTOR (7 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_count1_q : STD_LOGIC_VECTOR (6 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_count1_i : UNSIGNED (6 downto 0);
    attribute preserve of u0_m0_wo0_wi0_r0_ra0_count1_i : signal is true;
    signal u0_m0_wo0_wi0_r0_ra0_count1_eq : std_logic;
    attribute preserve of u0_m0_wo0_wi0_r0_ra0_count1_eq : signal is true;
    signal u0_m0_wo0_wi0_r0_ra0_add_0_0_a : STD_LOGIC_VECTOR (8 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_add_0_0_b : STD_LOGIC_VECTOR (8 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_add_0_0_o : STD_LOGIC_VECTOR (8 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_add_0_0_q : STD_LOGIC_VECTOR (8 downto 0);
    signal u0_m0_wo0_wi0_r0_wa0_q : STD_LOGIC_VECTOR (6 downto 0);
    signal u0_m0_wo0_wi0_r0_wa0_i : UNSIGNED (6 downto 0);
    attribute preserve of u0_m0_wo0_wi0_r0_wa0_i : signal is true;
    signal u0_m0_wo0_wi0_r0_memr0_reset0 : std_logic;
    signal u0_m0_wo0_wi0_r0_memr0_ia : STD_LOGIC_VECTOR (17 downto 0);
    signal u0_m0_wo0_wi0_r0_memr0_aa : STD_LOGIC_VECTOR (6 downto 0);
    signal u0_m0_wo0_wi0_r0_memr0_ab : STD_LOGIC_VECTOR (6 downto 0);
    signal u0_m0_wo0_wi0_r0_memr0_iq : STD_LOGIC_VECTOR (17 downto 0);
    signal u0_m0_wo0_wi0_r0_memr0_q : STD_LOGIC_VECTOR (17 downto 0);
    signal u0_m0_wo0_delsel_d_0_wi_0_s : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_delsel_d_0_wi_0_q : STD_LOGIC_VECTOR (17 downto 0);
    signal u0_m0_wo0_bank_memr0_reset0 : std_logic;
    signal u0_m0_wo0_bank_memr0_ia : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_bank_memr0_aa : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_bank_memr0_ab : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_bank_memr0_iq : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_bank_memr0_q : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_ca0_q : STD_LOGIC_VECTOR (6 downto 0);
    signal u0_m0_wo0_ca0_i : UNSIGNED (6 downto 0);
    attribute preserve of u0_m0_wo0_ca0_i : signal is true;
    signal u0_m0_wo0_ca0_eq : std_logic;
    attribute preserve of u0_m0_wo0_ca0_eq : signal is true;
    signal u0_m0_wo0_aseq_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_aseq_eq : std_logic;
    signal u0_m0_wo0_accum_a : STD_LOGIC_VECTOR (40 downto 0);
    signal u0_m0_wo0_accum_b : STD_LOGIC_VECTOR (40 downto 0);
    signal u0_m0_wo0_accum_i : STD_LOGIC_VECTOR (40 downto 0);
    signal u0_m0_wo0_accum_o : STD_LOGIC_VECTOR (40 downto 0);
    signal u0_m0_wo0_accum_q : STD_LOGIC_VECTOR (40 downto 0);
    signal u0_m0_wo0_oseq_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_oseq_eq : std_logic;
    signal u0_m0_wo0_oseq_gated_reg_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_ir_w_q : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_ir_w_i : UNSIGNED (1 downto 0);
    attribute preserve of u0_m0_wo0_ir_w_i : signal is true;
    signal u0_m0_wo0_ir_r_count0_q : STD_LOGIC_VECTOR (2 downto 0);
    signal u0_m0_wo0_ir_r_count0_i : UNSIGNED (1 downto 0);
    attribute preserve of u0_m0_wo0_ir_r_count0_i : signal is true;
    signal u0_m0_wo0_ir_d_reset0 : std_logic;
    signal u0_m0_wo0_ir_d_ia : STD_LOGIC_VECTOR (40 downto 0);
    signal u0_m0_wo0_ir_d_aa : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_ir_d_ab : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_ir_d_iq : STD_LOGIC_VECTOR (40 downto 0);
    signal u0_m0_wo0_ir_d_q : STD_LOGIC_VECTOR (40 downto 0);
    signal u0_m0_wo0_validdel_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_validdelRD_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_cm0_lutmem_reset0 : std_logic;
    signal u0_m0_wo0_cm0_lutmem_ia : STD_LOGIC_VECTOR (15 downto 0);
    signal u0_m0_wo0_cm0_lutmem_aa : STD_LOGIC_VECTOR (8 downto 0);
    signal u0_m0_wo0_cm0_lutmem_ab : STD_LOGIC_VECTOR (8 downto 0);
    signal u0_m0_wo0_cm0_lutmem_ir : STD_LOGIC_VECTOR (15 downto 0);
    signal u0_m0_wo0_cm0_lutmem_r : STD_LOGIC_VECTOR (15 downto 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_reset : std_logic;
    type u0_m0_wo0_mtree_mult1_0_cma_a0type is array(NATURAL range <>) of SIGNED(15 downto 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_a0 : u0_m0_wo0_mtree_mult1_0_cma_a0type(0 to 0);
    attribute preserve of u0_m0_wo0_mtree_mult1_0_cma_a0 : signal is true;
    type u0_m0_wo0_mtree_mult1_0_cma_c0type is array(NATURAL range <>) of SIGNED(17 downto 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_c0 : u0_m0_wo0_mtree_mult1_0_cma_c0type(0 to 0);
    attribute preserve of u0_m0_wo0_mtree_mult1_0_cma_c0 : signal is true;
    type u0_m0_wo0_mtree_mult1_0_cma_ptype is array(NATURAL range <>) of SIGNED(33 downto 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_p : u0_m0_wo0_mtree_mult1_0_cma_ptype(0 to 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_u : u0_m0_wo0_mtree_mult1_0_cma_ptype(0 to 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_w : u0_m0_wo0_mtree_mult1_0_cma_ptype(0 to 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_x : u0_m0_wo0_mtree_mult1_0_cma_ptype(0 to 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_y : u0_m0_wo0_mtree_mult1_0_cma_ptype(0 to 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_s : u0_m0_wo0_mtree_mult1_0_cma_ptype(0 to 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_qq : STD_LOGIC_VECTOR (33 downto 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_q : STD_LOGIC_VECTOR (33 downto 0);
    signal u0_m0_wo0_mtree_mult1_0_cma_ena0 : std_logic;
    signal u0_m0_wo0_mtree_mult1_0_cma_ena1 : std_logic;
    signal d_bank_u0_m0_wi0_wo0_merged_bit_select_c_13_q : STD_LOGIC_VECTOR (17 downto 0);
    signal input_valid_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_count0_run_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_oseq_gated_q : STD_LOGIC_VECTOR (0 downto 0);
    signal u0_m0_wo0_sysROB_and_q : STD_LOGIC_VECTOR (0 downto 0);
    signal xIn_bankIn_0_q : STD_LOGIC_VECTOR (19 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_count1_lut_q : STD_LOGIC_VECTOR (7 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_resize_in : STD_LOGIC_VECTOR (6 downto 0);
    signal u0_m0_wo0_wi0_r0_ra0_resize_b : STD_LOGIC_VECTOR (6 downto 0);
    signal u0_m0_wo0_cab0_q : STD_LOGIC_VECTOR (8 downto 0);
    signal u0_m0_wo0_ir_r_resize_in : STD_LOGIC_VECTOR (1 downto 0);
    signal u0_m0_wo0_ir_r_resize_b : STD_LOGIC_VECTOR (1 downto 0);
    signal out0_m0_wo0_lineup_select_delay_0_q : STD_LOGIC_VECTOR (0 downto 0);
    signal bank_u0_m0_wi0_wo0_merged_bit_select_b : STD_LOGIC_VECTOR (1 downto 0);
    signal bank_u0_m0_wi0_wo0_merged_bit_select_c : STD_LOGIC_VECTOR (17 downto 0);
    signal out0_m0_wo0_assign_id3_q : STD_LOGIC_VECTOR (0 downto 0);

begin


    -- u0_m0_wo0_ir_r_count0(COUNTER,79)@17
    -- low=0, high=3, step=1, init=0
    u0_m0_wo0_ir_r_count0_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_ir_r_count0_i <= TO_UNSIGNED(0, 2);
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_oseq_gated_reg_q = "1") THEN
                u0_m0_wo0_ir_r_count0_i <= u0_m0_wo0_ir_r_count0_i + 1;
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_ir_r_count0_q <= STD_LOGIC_VECTOR(STD_LOGIC_VECTOR(RESIZE(u0_m0_wo0_ir_r_count0_i, 3)));

    -- u0_m0_wo0_ir_r_resize(BITSELECT,82)@17
    u0_m0_wo0_ir_r_resize_in <= STD_LOGIC_VECTOR(u0_m0_wo0_ir_r_count0_q(1 downto 0));
    u0_m0_wo0_ir_r_resize_b <= STD_LOGIC_VECTOR(u0_m0_wo0_ir_r_resize_in(1 downto 0));

    -- VCC(CONSTANT,1)@0
    VCC_q <= "1";

    -- input_valid(LOGICAL,3)@10
    input_valid_q <= xIn_v and enable_i;

    -- u0_m0_wo0_run(ENABLEGENERATOR,17)@10 + 2
    u0_m0_wo0_run_ctrl <= u0_m0_wo0_run_out & input_valid_q & u0_m0_wo0_run_enableQ;
    u0_m0_wo0_run_clkproc: PROCESS (clk, areset)
        variable u0_m0_wo0_run_enable_c : SIGNED(7 downto 0);
        variable u0_m0_wo0_run_inc : SIGNED(1 downto 0);
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_run_q <= "0";
            u0_m0_wo0_run_enable_c := TO_SIGNED(99, 8);
            u0_m0_wo0_run_enableQ <= "0";
            u0_m0_wo0_run_count <= "00";
            u0_m0_wo0_run_inc := (others => '0');
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_run_out = "1") THEN
                IF (u0_m0_wo0_run_enable_c(7) = '1') THEN
                    u0_m0_wo0_run_enable_c := u0_m0_wo0_run_enable_c - (-100);
                ELSE
                    u0_m0_wo0_run_enable_c := u0_m0_wo0_run_enable_c + (-1);
                END IF;
                u0_m0_wo0_run_enableQ <= STD_LOGIC_VECTOR(u0_m0_wo0_run_enable_c(7 downto 7));
            ELSE
                u0_m0_wo0_run_enableQ <= "0";
            END IF;
            CASE (u0_m0_wo0_run_ctrl) IS
                WHEN "000" | "001" => u0_m0_wo0_run_inc := "00";
                WHEN "010" | "011" => u0_m0_wo0_run_inc := "11";
                WHEN "100" => u0_m0_wo0_run_inc := "00";
                WHEN "101" => u0_m0_wo0_run_inc := "01";
                WHEN "110" => u0_m0_wo0_run_inc := "11";
                WHEN "111" => u0_m0_wo0_run_inc := "00";
                WHEN OTHERS => 
            END CASE;
            u0_m0_wo0_run_count <= STD_LOGIC_VECTOR(SIGNED(u0_m0_wo0_run_count) + SIGNED(u0_m0_wo0_run_inc));
            u0_m0_wo0_run_q <= u0_m0_wo0_run_out;
        END IF;
    END PROCESS;
    u0_m0_wo0_run_preEnaQ <= u0_m0_wo0_run_count(1 downto 1);
    u0_m0_wo0_run_out <= u0_m0_wo0_run_preEnaQ and VCC_q;

    -- u0_m0_wo0_memread(DELAY,18)@12
    u0_m0_wo0_memread : dspba_delay
    GENERIC MAP ( width => 1, depth => 1, reset_kind => "ASYNC" )
    PORT MAP ( xin => u0_m0_wo0_run_q, xout => u0_m0_wo0_memread_q, clk => clk, aclr => areset );

    -- u0_m0_wo0_compute(DELAY,20)@12
    u0_m0_wo0_compute : dspba_delay
    GENERIC MAP ( width => 1, depth => 2, reset_kind => "ASYNC" )
    PORT MAP ( xin => u0_m0_wo0_memread_q, xout => u0_m0_wo0_compute_q, clk => clk, aclr => areset );

    -- d_u0_m0_wo0_compute_q_15(DELAY,101)@12 + 3
    d_u0_m0_wo0_compute_q_15 : dspba_delay
    GENERIC MAP ( width => 1, depth => 3, reset_kind => "ASYNC" )
    PORT MAP ( xin => u0_m0_wo0_compute_q, xout => d_u0_m0_wo0_compute_q_15_q, clk => clk, aclr => areset );

    -- u0_m0_wo0_aseq(SEQUENCE,73)@15 + 1
    u0_m0_wo0_aseq_clkproc: PROCESS (clk, areset)
        variable u0_m0_wo0_aseq_c : SIGNED(8 downto 0);
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_aseq_c := "000000000";
            u0_m0_wo0_aseq_q <= "0";
            u0_m0_wo0_aseq_eq <= '0';
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (d_u0_m0_wo0_compute_q_15_q = "1") THEN
                IF (u0_m0_wo0_aseq_c = "000000000") THEN
                    u0_m0_wo0_aseq_eq <= '1';
                ELSE
                    u0_m0_wo0_aseq_eq <= '0';
                END IF;
                IF (u0_m0_wo0_aseq_eq = '1') THEN
                    u0_m0_wo0_aseq_c := u0_m0_wo0_aseq_c + 100;
                ELSE
                    u0_m0_wo0_aseq_c := u0_m0_wo0_aseq_c - 1;
                END IF;
                u0_m0_wo0_aseq_q <= STD_LOGIC_VECTOR(u0_m0_wo0_aseq_c(8 downto 8));
            END IF;
        END IF;
    END PROCESS;

    -- d_u0_m0_wo0_compute_q_16(DELAY,102)@15 + 1
    d_u0_m0_wo0_compute_q_16 : dspba_delay
    GENERIC MAP ( width => 1, depth => 1, reset_kind => "ASYNC" )
    PORT MAP ( xin => d_u0_m0_wo0_compute_q_15_q, xout => d_u0_m0_wo0_compute_q_16_q, clk => clk, aclr => areset );

    -- u0_m0_wo0_wi0_r0_ra0_count1(COUNTER,28)@12
    -- low=0, high=100, step=1, init=1
    u0_m0_wo0_wi0_r0_ra0_count1_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_wi0_r0_ra0_count1_i <= TO_UNSIGNED(1, 7);
            u0_m0_wo0_wi0_r0_ra0_count1_eq <= '0';
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_memread_q = "1") THEN
                IF (u0_m0_wo0_wi0_r0_ra0_count1_i = TO_UNSIGNED(99, 7)) THEN
                    u0_m0_wo0_wi0_r0_ra0_count1_eq <= '1';
                ELSE
                    u0_m0_wo0_wi0_r0_ra0_count1_eq <= '0';
                END IF;
                IF (u0_m0_wo0_wi0_r0_ra0_count1_eq = '1') THEN
                    u0_m0_wo0_wi0_r0_ra0_count1_i <= u0_m0_wo0_wi0_r0_ra0_count1_i + 28;
                ELSE
                    u0_m0_wo0_wi0_r0_ra0_count1_i <= u0_m0_wo0_wi0_r0_ra0_count1_i + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_wi0_r0_ra0_count1_q <= STD_LOGIC_VECTOR(STD_LOGIC_VECTOR(RESIZE(u0_m0_wo0_wi0_r0_ra0_count1_i, 7)));

    -- u0_m0_wo0_wi0_r0_ra0_count1_lut(LOOKUP,26)@12
    u0_m0_wo0_wi0_r0_ra0_count1_lut_combproc: PROCESS (u0_m0_wo0_wi0_r0_ra0_count1_q)
    BEGIN
        -- Begin reserved scope level
        CASE (u0_m0_wo0_wi0_r0_ra0_count1_q) IS
            WHEN "0000000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01100101";
            WHEN "0000001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01100110";
            WHEN "0000010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01100111";
            WHEN "0000011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01101000";
            WHEN "0000100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01101001";
            WHEN "0000101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01101010";
            WHEN "0000110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01101011";
            WHEN "0000111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01101100";
            WHEN "0001000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01101101";
            WHEN "0001001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01101110";
            WHEN "0001010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01101111";
            WHEN "0001011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01110000";
            WHEN "0001100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01110001";
            WHEN "0001101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01110010";
            WHEN "0001110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01110011";
            WHEN "0001111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01110100";
            WHEN "0010000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01110101";
            WHEN "0010001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01110110";
            WHEN "0010010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01110111";
            WHEN "0010011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01111000";
            WHEN "0010100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01111001";
            WHEN "0010101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01111010";
            WHEN "0010110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01111011";
            WHEN "0010111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01111100";
            WHEN "0011000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01111101";
            WHEN "0011001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01111110";
            WHEN "0011010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01111111";
            WHEN "0011011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00000000";
            WHEN "0011100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00000001";
            WHEN "0011101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00000010";
            WHEN "0011110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00000011";
            WHEN "0011111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00000100";
            WHEN "0100000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00000101";
            WHEN "0100001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00000110";
            WHEN "0100010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00000111";
            WHEN "0100011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00001000";
            WHEN "0100100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00001001";
            WHEN "0100101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00001010";
            WHEN "0100110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00001011";
            WHEN "0100111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00001100";
            WHEN "0101000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00001101";
            WHEN "0101001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00001110";
            WHEN "0101010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00001111";
            WHEN "0101011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00010000";
            WHEN "0101100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00010001";
            WHEN "0101101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00010010";
            WHEN "0101110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00010011";
            WHEN "0101111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00010100";
            WHEN "0110000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00010101";
            WHEN "0110001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00010110";
            WHEN "0110010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00010111";
            WHEN "0110011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00011000";
            WHEN "0110100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00011001";
            WHEN "0110101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00011010";
            WHEN "0110110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00011011";
            WHEN "0110111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00011100";
            WHEN "0111000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00011101";
            WHEN "0111001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00011110";
            WHEN "0111010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00011111";
            WHEN "0111011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00100000";
            WHEN "0111100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00100001";
            WHEN "0111101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00100010";
            WHEN "0111110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00100011";
            WHEN "0111111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00100100";
            WHEN "1000000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00100101";
            WHEN "1000001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00100110";
            WHEN "1000010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00100111";
            WHEN "1000011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00101000";
            WHEN "1000100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00101001";
            WHEN "1000101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00101010";
            WHEN "1000110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00101011";
            WHEN "1000111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00101100";
            WHEN "1001000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00101101";
            WHEN "1001001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00101110";
            WHEN "1001010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00101111";
            WHEN "1001011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00110000";
            WHEN "1001100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00110001";
            WHEN "1001101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00110010";
            WHEN "1001110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00110011";
            WHEN "1001111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00110100";
            WHEN "1010000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00110101";
            WHEN "1010001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00110110";
            WHEN "1010010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00110111";
            WHEN "1010011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00111000";
            WHEN "1010100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00111001";
            WHEN "1010101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00111010";
            WHEN "1010110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00111011";
            WHEN "1010111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00111100";
            WHEN "1011000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00111101";
            WHEN "1011001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00111110";
            WHEN "1011010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "00111111";
            WHEN "1011011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01000000";
            WHEN "1011100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01000001";
            WHEN "1011101" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01000010";
            WHEN "1011110" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01000011";
            WHEN "1011111" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01000100";
            WHEN "1100000" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01000101";
            WHEN "1100001" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01000110";
            WHEN "1100010" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01000111";
            WHEN "1100011" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01001000";
            WHEN "1100100" => u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= "01001001";
            WHEN OTHERS => -- unreachable
                           u0_m0_wo0_wi0_r0_ra0_count1_lut_q <= (others => '-');
        END CASE;
        -- End reserved scope level
    END PROCESS;

    -- u0_m0_wo0_wi0_r0_ra0_count1_lutreg(REG,27)@12
    u0_m0_wo0_wi0_r0_ra0_count1_lutreg_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_wi0_r0_ra0_count1_lutreg_q <= "01100101";
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_memread_q = "1") THEN
                u0_m0_wo0_wi0_r0_ra0_count1_lutreg_q <= STD_LOGIC_VECTOR(u0_m0_wo0_wi0_r0_ra0_count1_lut_q);
            END IF;
        END IF;
    END PROCESS;

    -- u0_m0_wo0_wi0_r0_ra0_count0_inner(COUNTER,23)@12
    -- low=-1, high=99, step=-1, init=99
    u0_m0_wo0_wi0_r0_ra0_count0_inner_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_wi0_r0_ra0_count0_inner_i <= TO_SIGNED(99, 8);
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_memread_q = "1") THEN
                IF (u0_m0_wo0_wi0_r0_ra0_count0_inner_i(7 downto 7) = "1") THEN
                    u0_m0_wo0_wi0_r0_ra0_count0_inner_i <= u0_m0_wo0_wi0_r0_ra0_count0_inner_i - 156;
                ELSE
                    u0_m0_wo0_wi0_r0_ra0_count0_inner_i <= u0_m0_wo0_wi0_r0_ra0_count0_inner_i - 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_wi0_r0_ra0_count0_inner_q <= STD_LOGIC_VECTOR(STD_LOGIC_VECTOR(RESIZE(u0_m0_wo0_wi0_r0_ra0_count0_inner_i, 8)));

    -- u0_m0_wo0_wi0_r0_ra0_count0_run(LOGICAL,24)@12
    u0_m0_wo0_wi0_r0_ra0_count0_run_q <= STD_LOGIC_VECTOR(u0_m0_wo0_wi0_r0_ra0_count0_inner_q(7 downto 7));

    -- u0_m0_wo0_wi0_r0_ra0_count0(COUNTER,25)@12
    -- low=0, high=127, step=1, init=0
    u0_m0_wo0_wi0_r0_ra0_count0_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_wi0_r0_ra0_count0_i <= TO_UNSIGNED(0, 7);
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_memread_q = "1" and u0_m0_wo0_wi0_r0_ra0_count0_run_q = "1") THEN
                u0_m0_wo0_wi0_r0_ra0_count0_i <= u0_m0_wo0_wi0_r0_ra0_count0_i + 1;
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_wi0_r0_ra0_count0_q <= STD_LOGIC_VECTOR(STD_LOGIC_VECTOR(RESIZE(u0_m0_wo0_wi0_r0_ra0_count0_i, 8)));

    -- u0_m0_wo0_wi0_r0_ra0_add_0_0(ADD,29)@12 + 1
    u0_m0_wo0_wi0_r0_ra0_add_0_0_a <= STD_LOGIC_VECTOR("0" & u0_m0_wo0_wi0_r0_ra0_count0_q);
    u0_m0_wo0_wi0_r0_ra0_add_0_0_b <= STD_LOGIC_VECTOR("0" & u0_m0_wo0_wi0_r0_ra0_count1_lutreg_q);
    u0_m0_wo0_wi0_r0_ra0_add_0_0_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_wi0_r0_ra0_add_0_0_o <= (others => '0');
        ELSIF (clk'EVENT AND clk = '1') THEN
            u0_m0_wo0_wi0_r0_ra0_add_0_0_o <= STD_LOGIC_VECTOR(UNSIGNED(u0_m0_wo0_wi0_r0_ra0_add_0_0_a) + UNSIGNED(u0_m0_wo0_wi0_r0_ra0_add_0_0_b));
        END IF;
    END PROCESS;
    u0_m0_wo0_wi0_r0_ra0_add_0_0_q <= u0_m0_wo0_wi0_r0_ra0_add_0_0_o(8 downto 0);

    -- u0_m0_wo0_wi0_r0_ra0_resize(BITSELECT,30)@13
    u0_m0_wo0_wi0_r0_ra0_resize_in <= STD_LOGIC_VECTOR(u0_m0_wo0_wi0_r0_ra0_add_0_0_q(6 downto 0));
    u0_m0_wo0_wi0_r0_ra0_resize_b <= STD_LOGIC_VECTOR(u0_m0_wo0_wi0_r0_ra0_resize_in(6 downto 0));

    -- d_xIn_bankIn_0_12(DELAY,96)@10 + 2
    d_xIn_bankIn_0_12 : dspba_delay
    GENERIC MAP ( width => 2, depth => 2, reset_kind => "ASYNC" )
    PORT MAP ( xin => bankIn_0, xout => d_xIn_bankIn_0_12_q, clk => clk, aclr => areset );

    -- d_xIn_0_12(DELAY,95)@10 + 2
    d_xIn_0_12 : dspba_delay
    GENERIC MAP ( width => 18, depth => 2, reset_kind => "ASYNC" )
    PORT MAP ( xin => xIn_0, xout => d_xIn_0_12_q, clk => clk, aclr => areset );

    -- xIn_bankIn_0(BITJOIN,4)@12
    xIn_bankIn_0_q <= d_xIn_bankIn_0_12_q & d_xIn_0_12_q;

    -- bank_u0_m0_wi0_wo0_merged_bit_select(BITSELECT,94)@12
    bank_u0_m0_wi0_wo0_merged_bit_select_b <= STD_LOGIC_VECTOR(xIn_bankIn_0_q(19 downto 18));
    bank_u0_m0_wi0_wo0_merged_bit_select_c <= STD_LOGIC_VECTOR(xIn_bankIn_0_q(17 downto 0));

    -- d_bank_u0_m0_wi0_wo0_merged_bit_select_c_13(DELAY,103)@12 + 1
    d_bank_u0_m0_wi0_wo0_merged_bit_select_c_13 : dspba_delay
    GENERIC MAP ( width => 18, depth => 1, reset_kind => "ASYNC" )
    PORT MAP ( xin => bank_u0_m0_wi0_wo0_merged_bit_select_c, xout => d_bank_u0_m0_wi0_wo0_merged_bit_select_c_13_q, clk => clk, aclr => areset );

    -- d_in0_m0_wi0_wo0_assign_id1_q_12(DELAY,99)@10 + 2
    d_in0_m0_wi0_wo0_assign_id1_q_12 : dspba_delay
    GENERIC MAP ( width => 1, depth => 2, reset_kind => "ASYNC" )
    PORT MAP ( xin => input_valid_q, xout => d_in0_m0_wi0_wo0_assign_id1_q_12_q, clk => clk, aclr => areset );

    -- d_in0_m0_wi0_wo0_assign_id1_q_13(DELAY,100)@12 + 1
    d_in0_m0_wi0_wo0_assign_id1_q_13 : dspba_delay
    GENERIC MAP ( width => 1, depth => 1, reset_kind => "ASYNC" )
    PORT MAP ( xin => d_in0_m0_wi0_wo0_assign_id1_q_12_q, xout => d_in0_m0_wi0_wo0_assign_id1_q_13_q, clk => clk, aclr => areset );

    -- u0_m0_wo0_wi0_r0_wa0(COUNTER,31)@13
    -- low=0, high=127, step=1, init=73
    u0_m0_wo0_wi0_r0_wa0_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_wi0_r0_wa0_i <= TO_UNSIGNED(73, 7);
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (d_in0_m0_wi0_wo0_assign_id1_q_13_q = "1") THEN
                u0_m0_wo0_wi0_r0_wa0_i <= u0_m0_wo0_wi0_r0_wa0_i + 1;
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_wi0_r0_wa0_q <= STD_LOGIC_VECTOR(STD_LOGIC_VECTOR(RESIZE(u0_m0_wo0_wi0_r0_wa0_i, 7)));

    -- u0_m0_wo0_wi0_r0_memr0(DUALMEM,32)@13
    u0_m0_wo0_wi0_r0_memr0_ia <= STD_LOGIC_VECTOR(d_bank_u0_m0_wi0_wo0_merged_bit_select_c_13_q);
    u0_m0_wo0_wi0_r0_memr0_aa <= u0_m0_wo0_wi0_r0_wa0_q;
    u0_m0_wo0_wi0_r0_memr0_ab <= u0_m0_wo0_wi0_r0_ra0_resize_b;
    u0_m0_wo0_wi0_r0_memr0_dmem : altera_syncram
    GENERIC MAP (
        ram_block_type => "M10K",
        operation_mode => "DUAL_PORT",
        width_a => 18,
        widthad_a => 7,
        numwords_a => 128,
        width_b => 18,
        widthad_b => 7,
        numwords_b => 128,
        lpm_type => "altera_syncram",
        width_byteena_a => 1,
        address_reg_b => "CLOCK0",
        indata_reg_b => "CLOCK0",
        rdcontrol_reg_b => "CLOCK0",
        byteena_reg_b => "CLOCK0",
        outdata_reg_b => "CLOCK0",
        outdata_aclr_b => "NONE",
        clock_enable_input_a => "NORMAL",
        clock_enable_input_b => "NORMAL",
        clock_enable_output_b => "NORMAL",
        read_during_write_mode_mixed_ports => "DONT_CARE",
        power_up_uninitialized => "FALSE",
        init_file => "UNUSED",
        intended_device_family => "Cyclone V"
    )
    PORT MAP (
        clocken0 => '1',
        clock0 => clk,
        address_a => u0_m0_wo0_wi0_r0_memr0_aa,
        data_a => u0_m0_wo0_wi0_r0_memr0_ia,
        wren_a => d_in0_m0_wi0_wo0_assign_id1_q_13_q(0),
        address_b => u0_m0_wo0_wi0_r0_memr0_ab,
        q_b => u0_m0_wo0_wi0_r0_memr0_iq
    );
    u0_m0_wo0_wi0_r0_memr0_q <= u0_m0_wo0_wi0_r0_memr0_iq(17 downto 0);

    -- d_xIn_xIn_mode_12(DELAY,97)@10 + 2
    d_xIn_xIn_mode_12 : dspba_delay
    GENERIC MAP ( width => 2, depth => 2, reset_kind => "ASYNC" )
    PORT MAP ( xin => xIn_mode, xout => d_xIn_xIn_mode_12_q, clk => clk, aclr => areset );

    -- u0_m0_wo0_mode(REG,21)@12 + 1
    u0_m0_wo0_mode_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_mode_q <= "00";
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (d_in0_m0_wi0_wo0_assign_id1_q_12_q = "1") THEN
                u0_m0_wo0_mode_q <= STD_LOGIC_VECTOR(d_xIn_xIn_mode_12_q);
            END IF;
        END IF;
    END PROCESS;

    -- u0_m0_wo0_delsel_d_0_wi_0(MUX,63)@13 + 1
    u0_m0_wo0_delsel_d_0_wi_0_s <= u0_m0_wo0_mode_q;
    u0_m0_wo0_delsel_d_0_wi_0_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_delsel_d_0_wi_0_q <= (others => '0');
        ELSIF (clk'EVENT AND clk = '1') THEN
            CASE (u0_m0_wo0_delsel_d_0_wi_0_s) IS
                WHEN "00" => u0_m0_wo0_delsel_d_0_wi_0_q <= u0_m0_wo0_wi0_r0_memr0_q;
                WHEN "01" => u0_m0_wo0_delsel_d_0_wi_0_q <= u0_m0_wo0_wi0_r0_memr0_q;
                WHEN "10" => u0_m0_wo0_delsel_d_0_wi_0_q <= u0_m0_wo0_wi0_r0_memr0_q;
                WHEN "11" => u0_m0_wo0_delsel_d_0_wi_0_q <= u0_m0_wo0_wi0_r0_memr0_q;
                WHEN OTHERS => u0_m0_wo0_delsel_d_0_wi_0_q <= (others => '0');
            END CASE;
        END IF;
    END PROCESS;

    -- u0_m0_wo0_bank_memr0(DUALMEM,65)@12
    u0_m0_wo0_bank_memr0_ia <= bank_u0_m0_wi0_wo0_merged_bit_select_b;
    u0_m0_wo0_bank_memr0_aa <= GND_q;
    u0_m0_wo0_bank_memr0_ab <= GND_q;
    u0_m0_wo0_bank_memr0_dmem : altera_syncram
    GENERIC MAP (
        ram_block_type => "MLAB",
        operation_mode => "DUAL_PORT",
        width_a => 2,
        widthad_a => 1,
        numwords_a => 2,
        width_b => 2,
        widthad_b => 1,
        numwords_b => 2,
        lpm_type => "altera_syncram",
        width_byteena_a => 1,
        address_reg_b => "CLOCK0",
        indata_reg_b => "CLOCK0",
        rdcontrol_reg_b => "CLOCK0",
        byteena_reg_b => "CLOCK0",
        outdata_reg_b => "CLOCK0",
        outdata_aclr_b => "NONE",
        clock_enable_input_a => "NORMAL",
        clock_enable_input_b => "NORMAL",
        clock_enable_output_b => "NORMAL",
        read_during_write_mode_mixed_ports => "DONT_CARE",
        power_up_uninitialized => "FALSE",
        init_file => "UNUSED",
        intended_device_family => "Cyclone V"
    )
    PORT MAP (
        clocken0 => '1',
        clock0 => clk,
        address_a => u0_m0_wo0_bank_memr0_aa,
        data_a => u0_m0_wo0_bank_memr0_ia,
        wren_a => d_in0_m0_wi0_wo0_assign_id1_q_12_q(0),
        address_b => u0_m0_wo0_bank_memr0_ab,
        q_b => u0_m0_wo0_bank_memr0_iq
    );
    u0_m0_wo0_bank_memr0_q <= u0_m0_wo0_bank_memr0_iq(1 downto 0);

    -- u0_m0_wo0_ca0(COUNTER,66)@12
    -- low=0, high=100, step=1, init=0
    u0_m0_wo0_ca0_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_ca0_i <= TO_UNSIGNED(0, 7);
            u0_m0_wo0_ca0_eq <= '0';
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_compute_q = "1") THEN
                IF (u0_m0_wo0_ca0_i = TO_UNSIGNED(99, 7)) THEN
                    u0_m0_wo0_ca0_eq <= '1';
                ELSE
                    u0_m0_wo0_ca0_eq <= '0';
                END IF;
                IF (u0_m0_wo0_ca0_eq = '1') THEN
                    u0_m0_wo0_ca0_i <= u0_m0_wo0_ca0_i + 28;
                ELSE
                    u0_m0_wo0_ca0_i <= u0_m0_wo0_ca0_i + 1;
                END IF;
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_ca0_q <= STD_LOGIC_VECTOR(STD_LOGIC_VECTOR(RESIZE(u0_m0_wo0_ca0_i, 7)));

    -- u0_m0_wo0_cab0(BITJOIN,67)@12
    u0_m0_wo0_cab0_q <= u0_m0_wo0_bank_memr0_q & u0_m0_wo0_ca0_q;

    -- u0_m0_wo0_cm0_lutmem(DUALMEM,92)@12 + 2
    u0_m0_wo0_cm0_lutmem_aa <= u0_m0_wo0_cab0_q;
    u0_m0_wo0_cm0_lutmem_reset0 <= areset;
    u0_m0_wo0_cm0_lutmem_dmem : altera_syncram
    GENERIC MAP (
        ram_block_type => "M10K",
        operation_mode => "ROM",
        width_a => 16,
        widthad_a => 9,
        numwords_a => 485,
        lpm_type => "altera_syncram",
        width_byteena_a => 1,
        outdata_reg_a => "CLOCK0",
        outdata_aclr_a => "CLEAR0",
        clock_enable_input_a => "NORMAL",
        power_up_uninitialized => "FALSE",
        init_file => "FIR_0002_rtl_core_u0_m0_wo0_cm0_lutmem.hex",
        init_file_layout => "PORT_A",
        intended_device_family => "Cyclone V"
    )
    PORT MAP (
        clocken0 => '1',
        aclr0 => u0_m0_wo0_cm0_lutmem_reset0,
        clock0 => clk,
        address_a => u0_m0_wo0_cm0_lutmem_aa,
        q_a => u0_m0_wo0_cm0_lutmem_ir
    );
    u0_m0_wo0_cm0_lutmem_r <= u0_m0_wo0_cm0_lutmem_ir(15 downto 0);

    -- u0_m0_wo0_mtree_mult1_0_cma(CHAINMULTADD,93)@14 + 2
    u0_m0_wo0_mtree_mult1_0_cma_reset <= areset;
    u0_m0_wo0_mtree_mult1_0_cma_ena0 <= '1';
    u0_m0_wo0_mtree_mult1_0_cma_ena1 <= u0_m0_wo0_mtree_mult1_0_cma_ena0;
    u0_m0_wo0_mtree_mult1_0_cma_p(0) <= u0_m0_wo0_mtree_mult1_0_cma_a0(0) * u0_m0_wo0_mtree_mult1_0_cma_c0(0);
    u0_m0_wo0_mtree_mult1_0_cma_u(0) <= RESIZE(u0_m0_wo0_mtree_mult1_0_cma_p(0),34);
    u0_m0_wo0_mtree_mult1_0_cma_w(0) <= u0_m0_wo0_mtree_mult1_0_cma_u(0);
    u0_m0_wo0_mtree_mult1_0_cma_x(0) <= u0_m0_wo0_mtree_mult1_0_cma_w(0);
    u0_m0_wo0_mtree_mult1_0_cma_y(0) <= u0_m0_wo0_mtree_mult1_0_cma_x(0);
    u0_m0_wo0_mtree_mult1_0_cma_chainmultadd_input: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_mtree_mult1_0_cma_a0 <= (others => (others => '0'));
            u0_m0_wo0_mtree_mult1_0_cma_c0 <= (others => (others => '0'));
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_mtree_mult1_0_cma_ena0 = '1') THEN
                u0_m0_wo0_mtree_mult1_0_cma_a0(0) <= RESIZE(SIGNED(u0_m0_wo0_cm0_lutmem_r),16);
                u0_m0_wo0_mtree_mult1_0_cma_c0(0) <= RESIZE(SIGNED(u0_m0_wo0_delsel_d_0_wi_0_q),18);
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_mtree_mult1_0_cma_chainmultadd_output: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_mtree_mult1_0_cma_s <= (others => (others => '0'));
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_mtree_mult1_0_cma_ena1 = '1') THEN
                u0_m0_wo0_mtree_mult1_0_cma_s(0) <= u0_m0_wo0_mtree_mult1_0_cma_y(0);
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_mtree_mult1_0_cma_delay : dspba_delay
    GENERIC MAP ( width => 34, depth => 0, reset_kind => "ASYNC" )
    PORT MAP ( xin => STD_LOGIC_VECTOR(u0_m0_wo0_mtree_mult1_0_cma_s(0)(33 downto 0)), xout => u0_m0_wo0_mtree_mult1_0_cma_qq, clk => clk, aclr => areset );
    u0_m0_wo0_mtree_mult1_0_cma_q <= STD_LOGIC_VECTOR(u0_m0_wo0_mtree_mult1_0_cma_qq(33 downto 0));

    -- u0_m0_wo0_accum(ADD,74)@16 + 1
    u0_m0_wo0_accum_a <= STD_LOGIC_VECTOR(STD_LOGIC_VECTOR((40 downto 34 => u0_m0_wo0_mtree_mult1_0_cma_q(33)) & u0_m0_wo0_mtree_mult1_0_cma_q));
    u0_m0_wo0_accum_b <= STD_LOGIC_VECTOR(u0_m0_wo0_accum_q);
    u0_m0_wo0_accum_i <= u0_m0_wo0_accum_a;
    u0_m0_wo0_accum_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_accum_o <= (others => '0');
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (d_u0_m0_wo0_compute_q_16_q = "1") THEN
                IF (u0_m0_wo0_aseq_q = "1") THEN
                    u0_m0_wo0_accum_o <= u0_m0_wo0_accum_i;
                ELSE
                    u0_m0_wo0_accum_o <= STD_LOGIC_VECTOR(SIGNED(u0_m0_wo0_accum_a) + SIGNED(u0_m0_wo0_accum_b));
                END IF;
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_accum_q <= u0_m0_wo0_accum_o(40 downto 0);

    -- u0_m0_wo0_oseq(SEQUENCE,75)@15 + 1
    u0_m0_wo0_oseq_clkproc: PROCESS (clk, areset)
        variable u0_m0_wo0_oseq_c : SIGNED(8 downto 0);
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_oseq_c := "001100100";
            u0_m0_wo0_oseq_q <= "0";
            u0_m0_wo0_oseq_eq <= '0';
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (d_u0_m0_wo0_compute_q_15_q = "1") THEN
                IF (u0_m0_wo0_oseq_c = "000000000") THEN
                    u0_m0_wo0_oseq_eq <= '1';
                ELSE
                    u0_m0_wo0_oseq_eq <= '0';
                END IF;
                IF (u0_m0_wo0_oseq_eq = '1') THEN
                    u0_m0_wo0_oseq_c := u0_m0_wo0_oseq_c + 100;
                ELSE
                    u0_m0_wo0_oseq_c := u0_m0_wo0_oseq_c - 1;
                END IF;
                u0_m0_wo0_oseq_q <= STD_LOGIC_VECTOR(u0_m0_wo0_oseq_c(8 downto 8));
            END IF;
        END IF;
    END PROCESS;

    -- u0_m0_wo0_oseq_gated(LOGICAL,76)@16
    u0_m0_wo0_oseq_gated_q <= u0_m0_wo0_oseq_q and d_u0_m0_wo0_compute_q_16_q;

    -- u0_m0_wo0_oseq_gated_reg(REG,77)@16 + 1
    u0_m0_wo0_oseq_gated_reg_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_oseq_gated_reg_q <= "0";
        ELSIF (clk'EVENT AND clk = '1') THEN
            u0_m0_wo0_oseq_gated_reg_q <= STD_LOGIC_VECTOR(u0_m0_wo0_oseq_gated_q);
        END IF;
    END PROCESS;

    -- u0_m0_wo0_ir_w(COUNTER,78)@17
    -- low=0, high=3, step=1, init=3
    u0_m0_wo0_ir_w_clkproc: PROCESS (clk, areset)
    BEGIN
        IF (areset = '1') THEN
            u0_m0_wo0_ir_w_i <= TO_UNSIGNED(3, 2);
        ELSIF (clk'EVENT AND clk = '1') THEN
            IF (u0_m0_wo0_oseq_gated_reg_q = "1") THEN
                u0_m0_wo0_ir_w_i <= u0_m0_wo0_ir_w_i + 1;
            END IF;
        END IF;
    END PROCESS;
    u0_m0_wo0_ir_w_q <= STD_LOGIC_VECTOR(STD_LOGIC_VECTOR(RESIZE(u0_m0_wo0_ir_w_i, 2)));

    -- u0_m0_wo0_ir_d(DUALMEM,83)@17
    u0_m0_wo0_ir_d_ia <= u0_m0_wo0_accum_q;
    u0_m0_wo0_ir_d_aa <= u0_m0_wo0_ir_w_q;
    u0_m0_wo0_ir_d_ab <= u0_m0_wo0_ir_r_resize_b;
    u0_m0_wo0_ir_d_dmem : altera_syncram
    GENERIC MAP (
        ram_block_type => "MLAB",
        operation_mode => "DUAL_PORT",
        width_a => 41,
        widthad_a => 2,
        numwords_a => 4,
        width_b => 41,
        widthad_b => 2,
        numwords_b => 4,
        lpm_type => "altera_syncram",
        width_byteena_a => 1,
        address_reg_b => "CLOCK0",
        indata_reg_b => "CLOCK0",
        rdcontrol_reg_b => "CLOCK0",
        byteena_reg_b => "CLOCK0",
        outdata_reg_b => "CLOCK0",
        outdata_aclr_b => "NONE",
        clock_enable_input_a => "NORMAL",
        clock_enable_input_b => "NORMAL",
        clock_enable_output_b => "NORMAL",
        read_during_write_mode_mixed_ports => "DONT_CARE",
        power_up_uninitialized => "FALSE",
        init_file => "UNUSED",
        intended_device_family => "Cyclone V"
    )
    PORT MAP (
        clocken0 => '1',
        clock0 => clk,
        address_a => u0_m0_wo0_ir_d_aa,
        data_a => u0_m0_wo0_ir_d_ia,
        wren_a => u0_m0_wo0_oseq_gated_reg_q(0),
        address_b => u0_m0_wo0_ir_d_ab,
        q_b => u0_m0_wo0_ir_d_iq
    );
    u0_m0_wo0_ir_d_q <= u0_m0_wo0_ir_d_iq(40 downto 0);

    -- GND(CONSTANT,0)@0
    GND_q <= "0";

    -- u0_m0_wo0_validdel(DELAY,84)@17
    u0_m0_wo0_validdel : dspba_delay
    GENERIC MAP ( width => 1, depth => 3, reset_kind => "ASYNC" )
    PORT MAP ( xin => VCC_q, xout => u0_m0_wo0_validdel_q, ena => u0_m0_wo0_oseq_gated_reg_q(0), clk => clk, aclr => areset );

    -- u0_m0_wo0_sysROB_and(LOGICAL,85)@17
    u0_m0_wo0_sysROB_and_q <= u0_m0_wo0_validdel_q and u0_m0_wo0_oseq_gated_reg_q;

    -- u0_m0_wo0_validdelRD(DELAY,86)@17
    u0_m0_wo0_validdelRD : dspba_delay
    GENERIC MAP ( width => 1, depth => 2, reset_kind => "ASYNC" )
    PORT MAP ( xin => u0_m0_wo0_sysROB_and_q, xout => u0_m0_wo0_validdelRD_q, clk => clk, aclr => areset );

    -- out0_m0_wo0_lineup_select_delay_0(DELAY,88)@17
    out0_m0_wo0_lineup_select_delay_0_q <= STD_LOGIC_VECTOR(u0_m0_wo0_validdelRD_q);

    -- out0_m0_wo0_assign_id3(DELAY,90)@17
    out0_m0_wo0_assign_id3_q <= STD_LOGIC_VECTOR(out0_m0_wo0_lineup_select_delay_0_q);

    -- xOut(PORTOUT,91)@17 + 1
    xOut_v <= out0_m0_wo0_assign_id3_q;
    xOut_c <= STD_LOGIC_VECTOR("0000000" & GND_q);
    xOut_0 <= u0_m0_wo0_ir_d_q;

END normal;
