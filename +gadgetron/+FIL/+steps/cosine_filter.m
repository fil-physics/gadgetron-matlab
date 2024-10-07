
function next = cosine_filter(input,W)

disp("Cosine filter setup...")

    function cosFilter = CosineFilter(N, w, symmetric)
        
        %**************************************************************************
        %   profile goes from 1 to 0 over some specified width.  The square of the
        %   cosine is used so that the fall is sufficiently rapid as to not be
        %   abrupt (since that will cause ringing).
        %
        %   Input:
        %       w           # pixels over which the signal falls to 0 with cosine
        %                   modulation. The filter will have 1 > w pixels > 0.
        %       N           Total number of points in the filter
        %       symmetric   Binary flag to indicate whether or not the filter
        %                   should be symmetric.  Default true: symmetric
        %
        %   Output:
        %       cosFilter
        %
        %   MFC 09.04.2013
        %
        %**************************************************************************
        
        % Parameter checks:
        switch nargin
            case 3
                if w > N/2
                    error('Maximum filter width is half the number of points')
                end
                
            case 2
                symmetric = true;
                if w > N/2
                    error('Maximum filter width is half the number of points')
                end
                
            case {1, 0}
                error('Need at least two parameters: N (# points) & w (width)');
        end
        
        % Actual filter (initially sized N+2 because I don't want the filter to
        % actually go to zero or it will mean I lose a data point):
        cosFilter = ones(N + 2, 1);
        cosFilter(end - w - 1: end, 1) = cos(linspace(0, pi/2, w + 2));
        
        if symmetric
            
            cosFilter(1 : w + 2) = cos(linspace(pi/2, 0, w + 2));
            
        end
        
        cosFilter = cosFilter(2 : end - 1).^2;
    end



    function data = cosine_filter(data)
        
        disp("Applying cosine filter...")
                
        % smooth the edges of the k-space to avoid ringing artefatcs
        % Cosine filter : 20% of the size of the k-space
        
        dims = size(data.data);
        
        dat=reshape(data.data,dims(1),dims(2),dims(3),dims(4),[]);
        
        for vol=1:size(dat,5)
            datToFilt = permute(squeeze(dat(:,:,:,:,vol)),[2 3 4 1]);
            
            [f1, f2, f3] = ndgrid(CosineFilter(dims(2), floor(dims(2)*W), 1), ...
                CosineFilter(dims(3),floor(dims(3)*W), 1), ...
                CosineFilter(dims(4), floor(dims(4)*W), 1));
            
            CosFilter=min(min(f1,f2),f3);
            
            filteredData(:,:,:,:,vol)=CosFilter.*datToFilt;
        end
        
        data.data=reshape(permute(filteredData,[4 1 2 3 5]),size(data.data));
        
    end


next = @() cosine_filter(input());
end
