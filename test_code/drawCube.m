function [h_comp, h_axs] = drawCube(ax, p, nv_comp, nv_axs)
% Draw cube spanned by coordinate origin and one 3d point
%
% ax        3d axes object to draw in
% p         3d coordinates of point that spans cube
% nv_comp	optional. 2-by-n cell array, in each row holding a name value pair 
%           for lines that connect coordinate planes to p, e.g. 
%           {'color', 'r'; 'linewidth', 3}
% nv_axs    optional. 2-by-n cell array, in each row holding a name value pair 
%           for lines lying in coordinate planes

if nargin < 3
    nv_comp = {'color', 'r'; 'linewidth', 1; 'linestyle', ':'};
end
if nargin < 4 
    nv_axs = {'color', 'b'; 'linewidth', 1; 'linestyle', ':'};
end
    
axes(ax);

h_comp = gobjects(3,1);
h_comp(1) = line([0,p(1)], [p(2),p(2)], [p(3),p(3)]);
h_comp(2) = line([p(1),p(1)], [0,p(2)], [p(3),p(3)]);
h_comp(3) = line([p(1),p(1)], [p(2),p(2)], [0,p(3)]);

h_axs = gobjects(9,1);
h_axs(1) = line([0,p(1)], [0,0], [0,0]);
h_axs(2) = line([0,0], [0,p(2)], [0,0]);
h_axs(3) = line([0,0], [0,0], [0,p(3)]);
h_axs(4) = line([p(1),p(1)], [0,p(2)], [0,0]);
h_axs(5) = line([0,p(1)], [p(2),p(2)], [0,0]);
h_axs(6) = line([0,p(1)], [0,0], [p(3),p(3)]);
h_axs(7) = line([0,0], [0,p(2)], [p(3),p(3)]);
h_axs(8) = line([p(1),p(1)], [0,0], [0,p(3)]);
h_axs(9) = line([0,0], [p(2),p(2)], [0,p(3)]);

for j = 1:size(nv_comp,1)
    set(h_comp, nv_comp{j,1}, nv_comp{j,2});
end

for j = 1:size(nv_axs,1)
    set(h_axs, nv_axs{j,1}, nv_axs{j,2});
end

end