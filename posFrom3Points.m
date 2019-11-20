function [pos] = posFrom3Points(p1, p2, p3, coeffs)    
% function [pos] = posFrom3Points(p1, p2, p3, coeffs)    
%
% Compute point in 3D space from three known points (marker data) and
% known coefficients that specify the relative position of the sought point 
% from those three points through their linear combination.
%
% The coefficients for a specific spatial configuration of markers (e.g.,
% mounted on a pointer device) and a specific relation to the sought point
% (e.g., the pointer tip), can be obtained using the function
% pointerCalibration.
%
% __Input__
%
% p1, p2, p3    Known points, each is a three-element vector.
%
% coeffs        Three-element vector of coefficients c1, c2, c3 specifying
%               position of pos in relation to p1, p2, p3.
%
% __Output__
%
% pos           Three-element vector, sought point. If input points are row
%               vectors, this will be a row vector as well and vice versa.
%
%
% __Notes__
%
% A plane is defined by support vector p1 and unit directional vectors
% u1 = p2-p1, u2 = p3-p1. The normal of that plane is unit vector
% u3 = (u1 × u2). The sought point is computed as the sum over u1, u2, u3
% modified by coefficients c1, c2, c3.
      
u1 = (p2-p1) / norm(p2-p1);
u2 = p3-p1;
u2 = u2 - u1 * dot(u2,u1); % adjust u2 to be orthogonal to u1
u2 = u2/norm(u2);
u3 = cross(u1,u2) / norm(cross(u1,u2)); 
pos = (p1 + coeffs(1) * u1 + coeffs(2) * u2 + coeffs(3) * u3);