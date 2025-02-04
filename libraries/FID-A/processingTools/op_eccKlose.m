% op_eccKlose.m
% Jamie Near, McGill University 2014.
% Georg Oeltzschner, Johns Hopkins University 2019.
% 
% USAGE:
% [out,outw]=op_eccKlose(in,inw);
% 
% DESCRIPTION:
% Perform a classic Klose eddy current correction (Klose, Magn Reson Med
% 14:26-30 (1990). The complex signal vector of the water-suppressed FID is
% divided by the phase vector of the water-unsuppressed FID. Both
% acquisitions need to be performed with identical gradient strenghts and 
% timing, so that the eddy current behavior is the same in both. 
% 
% INPUTS:
% in     = water suppressed input data in matlab structure format.
% inw    = water unsuppressed input data in matlab structure format.
%
% OUTPUTS:
% out    = Water suppressed output following eddy current correction  
% outw   = Water unsuppressed output following eddy current correction

function [out,outw]=op_eccKlose(in,inw)

if inw.dims.coils~=0 ||  inw.dims.subSpecs~=0 || inw.averages>1
    error('ERROR:  Must combine receivers, averages and subspecs prior to running ecc!! ABORTING!!');
end

% Determine the phase of the complex water FID.
inph=unwrap(angle(inw.fids));

% Now apply the eddy current correction to both the water-suppressed and the
% water-unsuppressed data:
out=in;
out.fids=out.fids.*exp(1i*-inph);
out.specs=fftshift(fft(out.fids,[],1),1);

outw=inw;
outw.fids=outw.fids.*exp(1i*-inph);
outw.specs=fftshift(fft(outw.fids,[],1),1);