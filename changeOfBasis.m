function [p_transformed, T, o] = changeOfBasis(p, om, xm, ym)
% function [p_transformed, T, o] = changeOfBasis(p, om, xm, ym)
%
% Transform coordinate vector to a new basis that is defined by means of
% three points: one at the new origin (om), one on the positive
% x-axis (xm), and one in the positive x-y-plane (ym).
%
% The origin of the new coordinate frame is at om, the positive x-axis 
% extends toward xm, the positive y-axis is perpendicular to the x-axis and 
% lies in the x-y-plane with ym, and the z-axis is defined as in a usual
% right-handed coordinate system. No scaling is done. 
%
% __Input__
%
% p     column vector, point to be transformed.
%
% om    column vector, origin of new coordinate frame.
% 
% xm    column vector, point on positive x axis of the new coordinate frame.
%
% ym    column vector, point in positive x-y-plane of new coordinate frame.
%
% __Output__
%
% p_transformed     Vector representation in the new coordinate system
%
% T                 Transformation matrix (do T*v to transform vector v to
%                   the new basis).
%
% o                 Translational vector to shift coordinates to the new
%                   origin. (do T*v+o to transform a vector v  into the new
%                   coordinate frame)


% new (unit) basis vectors
x_hat = (xm - om) / norm(xm - om);  
z_hat = cross(x_hat, (ym - om));     
z_hat = z_hat / norm(z_hat);
y_hat = cross(z_hat, x_hat);        

% new basis
A = [x_hat, y_hat, z_hat]; 

% original basis (not really necessary here, since standard basis is
% assumed; changing this would allow starting from arbitrary basis)
B = eye(numel(p)); 

% transformation matrix (B to A) 
T = inv(A) * B;

% transform to new basis
p_A = T * p;
o = -T * om;

% translate to new origin
p_transformed = p_A + o;

end
