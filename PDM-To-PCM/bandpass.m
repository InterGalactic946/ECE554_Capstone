% =========================================================================
% File: bandpass.m
%
% Description:
%   This script designs the compensation-aware FIR filters from bandpass.m
%   and exports their coefficients to text files for use in the Intel FIR II IP.
%
%   These filters are not plain bandpass filters. Their passband gains are
%   intentionally shaped so that the FIR response also compensates for:
%       1) CIC droop
%       2) microphone frequency response
%
%   Therefore, use these filters instead of a separate CIC compensation FIR.
%
% Outputs:
%   fir_coeff_all.txt -> 192 kHz bands 1 through 4 in multibank FIR IP format
%
% Notes:
%   - fir2() expects normalized frequency, where 1 corresponds to Nyquist.
%   - Filter order n = 100 means 101 taps.
%   - The export format is compatible with FIR II IP coefficient import.
%   - bPM0 is still computed but intentionally not written to file.
% =========================================================================

clear;
clc;

%% ------------------------------------------------------------------------
% User settings
% -------------------------------------------------------------------------
n = 100;              % FIR order -> 101 taps
B = 16;               % Coefficient bit width for fixed-point export
is_fxp = false;       % false -> export floating-point coefficients
                      % true  -> export signed integer coefficients

plot_filters = false;  % true -> open Filter Analyzer windows

%% ------------------------------------------------------------------------
% 48 kHz path filter
%
% This is a compensated lowpass-style filter:
%   passband:   0 to 10 kHz
%   transition: 10 to 11 kHz
%   stopband:   above 11 kHz
%
% Frequencies are normalized by Nyquist = 48 kHz.
% -------------------------------------------------------------------------
f0  = [0 10000 11000 48000];
fn0 = f0 ./ 48000;
A0  = [1 0.988 0 0];
bPM0 = fir2(n, fn0, A0);

%% ------------------------------------------------------------------------
% 192 kHz path - Band 1
%
% Passband roughly 10 kHz to 18 kHz.
% The passband slope is deliberate and folds compensation into the filter.
% Frequencies are normalized by Nyquist = 96 kHz.
% -------------------------------------------------------------------------
f1  = [0 9000 10000 18000 19000 96000];
fn1 = f1 ./ 96000;
A1  = [0 0 0.808 0.473 0 0];
bPM1 = fir2(n, fn1, A1);

%% ------------------------------------------------------------------------
% 192 kHz path - Band 2
% Passband roughly 18 kHz to 25 kHz.
% -------------------------------------------------------------------------
f2  = [0 17000 18000 25000 26000 96000];
fn2 = f2 ./ 96000;
A2  = [0 0 0.473 0.199 0 0];
bPM2 = fir2(n, fn2, A2);

%% ------------------------------------------------------------------------
% 192 kHz path - Band 3
% Passband roughly 25 kHz to 32 kHz.
% -------------------------------------------------------------------------
f3  = [0 24000 25000 32000 33000 96000];
fn3 = f3 ./ 96000;
A3  = [0 0 0.199 0.359 0 0];
bPM3 = fir2(n, fn3, A3);

%% ------------------------------------------------------------------------
% 192 kHz path - Band 4
% Passband roughly 32 kHz to 40 kHz.
% -------------------------------------------------------------------------
f4  = [0 31000 32000 40000 41000 96000];
fn4 = f4 ./ 96000;
A4  = [0 0 0.359 0.531 0 0];
bPM4 = fir2(n, fn4, A4);

%% ------------------------------------------------------------------------
% Optional visualization
% -------------------------------------------------------------------------
if plot_filters
    filterAnalyzer(bPM0);
    filterAnalyzer(bPM1);
    filterAnalyzer(bPM2);
    filterAnalyzer(bPM3);
    filterAnalyzer(bPM4);
end

%% ------------------------------------------------------------------------
% Export coefficients for FIR II IP
%
% bPM0 through bPM4 are exported into a single multibank coefficient file.
% -------------------------------------------------------------------------
write_multibank_coeff_file('./outputs/fir_coeff_all.txt', {bPM0, bPM1, bPM2, bPM3, bPM4}, is_fxp, B);

fprintf('\nAll coefficient files generated successfully.\n');

%% ========================================================================
% Local helpers
% ========================================================================
function write_multibank_coeff_file(filename, bank_coeffs, is_fxp, B)

    fid = fopen(filename, 'wt');
    if fid == -1
        error('Could not open %s for writing.', filename);
    end

    for mode_idx = 1:length(bank_coeffs)
        h = bank_coeffs{mode_idx};

        fprintf(fid, '# mode %d\n', mode_idx - 1);

        if is_fxp
            % Normalize before quantization so values fit signed B-bit range.
            h_norm = h / max(abs(h));
            h_quant = fix(h_norm * (2^(B-1) - 1));

            % Write all coefficients for this bank on one line (space separated)
            fprintf(fid, '%d ', h_quant);
        else
            % Export floating-point coefficients on one line
            fprintf(fid, '%.18f ', h);
        end

        fprintf(fid, '\n\n');
    end

    fclose(fid);

    fprintf('Saved coefficient file: %s\n', filename);
end
