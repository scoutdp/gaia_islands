classdef qgis_river_csv
    %for an exported csv of river profile data from qgis 
    
    %IMPORTANT: the following methods MUST be modified/personalized in order for the class to function: 
    %qgis_river_csv(), addToTable(), getColumn(), getColor(), getLegend(), getCsv() 

    properties
        totalTable %stores data for every island 
    end

    methods (Static)

        %PART ONE: building the data 

        %column order - 1:rivID, 2:X, 3:Y, 4:Z, 5:dist, 6:dir, 7:conc 
        %this method creates a cell array -- one row per river -- containing its initial 
        %ID, xydz data (stored as arrays), and the calculated concavity & direction 
        %this table only stores rivers that are deemed usable data (enough length, elevation, etc) 
        function cutTable = eliminateRivers(csvPath)
            file = readtable(csvPath);
            cutTable = cell(0,7);

            %RIV INDEX - creates an array of the start and end cell # for each river 
            rivIndex = zeros(0,2);
            rivIDs = file{:,1};
            start = 1;
                for search = 2:length(rivIDs)
                    if rivIDs(search) ~= rivIDs(search-1)
                        newRow = [start,search]; 
                        % first row is location of riv w ID 0 
                        rivIndex = [rivIndex; newRow];
                        start = search;
                    end 
                end 

            %where minimum starting length & elevation are determined  
            minEl = (max(file.Z)) * .1;
            minLe = (max(file.DISTANCE)) * .05;

            for rivNum = 0:(length(rivIndex) - 1) %go through each river on the island 

                %GET RIVER 
                riv = [];
                start = rivIndex(rivNum+1,1); %rivNum+1 catches the domino 
                fin = rivIndex(rivNum+1,2) - 1;
                    for search = start:fin 
                        newRow = file(search, :);
                        riv = [riv;newRow];
                    end 
                riv = sortrows(riv, "DISTANCE"); 
                if(height(riv) < 3)
                    continue;
                end 

                x = riv.X; 
                y = riv.Y;
                d = riv.DISTANCE; 
                z = riv.Z; 

                %normalize these data on 0-1 scale
                rd=rescale(d);  
                rz=rescale(z); 

                %CONDITIONAL STATEMENTS -- PERFORM IF TRUE 
                if(d(height(d))>minLe && z(height(z)) > minEl) %narrow to good rivers 

                        %CONCAVITY 
                        auc=trapz(rd,rz); %area under profile 
                        abt=.5-auc; %difference between curve & straight line 
                        conc=abt/.5; %concavity index from zaprowski 2005

                        %DIRECTION -- in radians (0-2pi) from start to end points
                        size = length(x); 
                        dir = atan2d((y(1)-y(size)),(x(1)-x(size)));
                        dir = deg2rad(dir);
                        newRow = {rivNum, x, y, z, d, dir, conc};
                        cutTable = [cutTable;newRow];
                end 
            end  

            %remove rivers with concavity outliers
            concz = cell2mat(cutTable(:,7));
            outs = isoutlier(concz); 
            for final = (height(cutTable)):-1:1 
                if(outs(final) == true)
                    cutTable(final, :) = []; 
                end 
            end 
            disp("completed: " + csvPath) 
        end 
    end 

    methods 

        %constructor - initializes totalTable with all data stored in sheet
        %1:name, 2:csvPath, 3: region, 4:cutTable, 5... other variables  
        function obj = qgis_river_csv(spreadSheetPath) 
            sheet = readtable(spreadSheetPath);
            obj.totalTable = cell(0,6); 

            %turn each spreadsheet row --> totalTable row 
            for search = 1:height(sheet)
                name = string(sheet.name{search}); %make sure to match to .csv col name 
                csvPath = string(sheet.path{search});
                region = string(sheet.region{search});
                %ADD/CHANGE/REMOVE VARIABLES & NAMES AS APPLICABLE TO THE INPUT SPREADSHEET 
                %if there is nothing additional, delete ', OTHER' wherever it is located. else, replace with col names 

                obj = obj.addToTable(name, csvPath, region, OTHER);
            end 
        end 

        %add input values to total table 
        %useful to have as a seperate method for the option to add additional islands later 
        function obj = addToTable(obj, name, csvPath, region, OTHER) 
            cutTable = qgis_river_csv.eliminateRivers(csvPath);
            newRow = {name, csvPath, region, cutTable, OTHER};
            obj.totalTable = [obj.totalTable; newRow];
        end
        

        %PART TWO: GETS 

        function colNum = getColumn(obj, property)
            if(strcmp(property, 'PROPERTYNAME1')) %update as applicable 
                colNum = COLNUM1;
            elseif(strcmp(property, 'PROPERTYNAME2'))
                colNum = COLNUM2;
            elseif(strcmp(property, 'concavity')) %leave as is for variable plot method 
                colNum = width(obj.totalTable) + 1;
            else 
                colNum = -1;
            end 
        end 

        %custom region colors for clarity 
        function color = getColor(obj, varargin)
            p = inputParser;
            addParameter(p, 'Region', '');
            addParameter(p, 'Island', '');
            parse(p, varargin{:});
            region = p.Results.Region;
            island = p.Results.Island;
            input = '';
            if ~isempty(region)
                input = region;
            elseif ~isempty(island)
                isNum = obj.getNumber(island);
                input = obj.totalTable{isNum,3};
            end
            
            if(strcmp(input, "REGION1")) %update the REGION# string names for method to work 
                color = [0.227 0.525 1]; %rgb decimal format
            elseif(strcmp(input, "REGION2"))
                color = [0.514 0.220 0.7410]; 
            elseif(strcmp(input, "REGION3"))
                color = [.23 .76 .29]; 
            elseif(strcmp(input, "REGION4"))
                color = [1 0 0.431];
            end 
        end 
        
        function lgd = getLegend(obj)
            pnt1 = scatter(0,0,0.1,obj.getColor('Region', "REGION1"), 'filled'); %update REGION# everywhere in method 
            pnt2 = scatter(0,0,0.1,obj.getColor('Region', "REGION2"), 'filled');
            pnt3 = scatter(0,0,0.1,obj.getColor('Region', "REGION3"), 'filled');
            pnt4 = scatter(0,-2,15,obj.getColor('Region', "REGION4"), 'filled');
            h = [pnt1 pnt2 pnt3, pnt4];
            lgd = legend(h, "REGION1", "REGION2", "REGION3", "REGION4"); %if there are less than 4 regions, DELETE pnt4, etc & remove names 
            lgd.Location = 'northwest';
        end 
        

        %given island string return column number in totalTable 
        function isNum = getNumber(obj, island)
            isNum = 0;
            island = string(island);
            for h = 1:height(obj.totalTable)
                table = string(obj.totalTable{h,1});
                if(strcmp(table,island))
                    isNum = h;
                end
            end 
        end 

        %returns a string with the average & std of concavity of an island 
        function txt = getConcavity(obj,island)
            isNum = obj.getNumber(island);
            current = obj.totalTable{isNum,4};
            concs = cell2mat(current(:,7));
            format long 
            avg = mean(concs);
            stdev = std(concs);
            name = obj.totalTable{isNum,1};
            txt = "Concavity of " + name + " is an average of " + avg + " with a standard deviation of " + stdev;
        end 
        
        %useful to visualize the rivers of cutTable in QGIS again - export
        %here as .csv and import there as delimited text layer 
        %layer the original & cut rivers to determine what isn't counted 
        function getCsv(obj, island)
            isNum = obj.getNumber(island);
            cutTable = obj.totalTable{isNum, 4};
            csvEdited = ["rivID", "x", "y", "z", "d"];
            for index = 1:height(cutTable)
                rivID = cutTable{index,1};
                x = cell2mat(cutTable(index,2));
                y = cell2mat(cutTable(index,3));
                z = cell2mat(cutTable(index,4));
                d = cell2mat(cutTable(index,5));
                rivIDs = zeros(length(x),1);
                rivIDs(:) = rivID;
                newRows = [rivIDs,x,y,z,d]; 
                csvEdited = [csvEdited;newRows];
            end 
 
            disp("completed: " + region) 
            filename = "...\matlab_csvs\" + island + "_usableRivers.csv"; %update to correct output file location 
            writematrix(csvEdited, filename);
        end 


        %PART THREE: DATA VISUALIZATION 
        
        %makes rose plot of each riv dir & conc for an island 
        function roseplot = rosePlot(obj, island)      
                
            isNum = obj.getNumber(island);
            color = obj.getColor('Island', island);
            roseplot = figure();
            array = obj.totalTable{isNum, 4};
            concs = cell2mat(array(:,7));
            dirs = cell2mat(array(:,6));
                for index = 1:height(array)
                    polarscatter(dirs(index), concs(index)+1, 15, color);
                        %conc is plotted as +1 so neg values are included
                    hold on
                end 
           
            rlim([0,2]);
            rticks([0 .5 1 1.5 2])
            rticklabels([-1 -.5 0 .5 1])
            title("concavity of each river scattered by direction; " + island)
            %this fixes the conc + 1 so labels represent true values 
        end 
        
        
        %rose diagram plotted by average concavity of 20 deg sections 
        function norRose = normalizedRose(obj,island)
            isNum = obj.getNumber(island);
            norRose = figure();
            array = obj.totalTable{isNum, 4};
            concsNdirs = cell2mat(array(:, 6:7));
            concsNdirs = sortrows(concsNdirs,1);
            %create concavity table for island sorted by inc direction,
            %which goes from -pi to +pi 
            p = pi/9;
            theta = [];
            bin = -pi;
            %set up arrays for the for loop to be plotted 
            
            for cap = -9:8
                %counting by groups of pi/9 (so there are 18 sections of 20
                %degrees around the circle) 
                sum = 0;
                count = 0;
                for index = 1:height(concsNdirs)
                    if (concsNdirs(index,1) >= (cap*p) && concsNdirs(index,1) < ((cap+1)*p))
                        sum = sum + concsNdirs(index,2);
                        count = count +1;
                        %if direction is in current normalized range, add
                        %concavity to sum & increase total 
                    end 
                end         
                mn = sum./count + 1;
                theta = [theta,mn];
                bin = [bin,(cap+1)*p];
                %calculate mean concavity for this section and add this and
                %the bin edge to their arrays 
            end 
           
            theta(isnan(theta)) = 0;
            color = obj.getColor('Island', island);
            polarhistogram('BinEdges',bin,'BinCounts',theta, 'FaceColor', color);
            %creates histogram from custom heights & edges 
           
            rlim([0,2]);
            rticks([0 .5 1 1.5 2])
            rticklabels([-1 -.5 0 .5 1])
            %this fixes the conc + 1 so labels represent true values 
            title("average river concavity of 20deg direction sections ; " + island)
        end 
        
        %plots every normalized river profile of an island on one figure  
        function normConcPlot = normConcavityPlot(obj, island)
            normConcPlot = figure();
            
            isNum = obj.getNumber(island);
            array = obj.totalTable{isNum, 4};
            total = height(array);
            
            for index = 1:total 
                d = cell2mat(array(index,5));
                z = cell2mat(array(index,4));
                rd=rescale(d);
                rz=rescale(z);
                plot(rd,rz);
                hold on
            end 
            set(gca, 'xdir', 'reverse')
            xlabel("Distance")
            ylabel("Elevation")
            title("normalized flow diagram; " + island)
        end 
        
        
        %plots every normalized river profile of an island on one figure  
        function spacConcPlot = spacialConcavityPlot(obj, island)
            spacConcPlot = figure();
                        
            isNum = obj.getNumber(island);
            array = obj.totalTable{isNum, 4};
            total = height(array);
            
            for index = 1:total 
                d = cell2mat(array(index,5));
                z = cell2mat(array(index,4));
                plot(d,z);
                hold on
            end 
            set(gca, 'xdir', 'reverse')
            xlabel("Distance")
            ylabel("Elevation")
            title("full flow diagram; " + island)
        end 
        
        %visualize river concavity data; can be sorted by a given variable,
        %limited to one region, and/or including a line best fit
        function concScatter = concavityScatter(obj, varargin)
            concScatter = figure();
            
            p = inputParser;
            addOptional(p, 'Variable', '')
            addOptional(p, 'Region', '')
            addOptional(p, 'LineFit', true, @islogical)
            parse(p, varargin{:});
            var = p.Results.Variable; %order concavity by a given variable (age, volume)
            region = p.Results.Region; %scatters data for the given region; else scatters all 
            lineFit = p.Results.LineFit; %include line best fit 
            
            names = [];
            match = cell(0,width(obj.totalTable));
            
            xt = [];
            y = [];
            
            %initialize match to narrow which islands are scattered 
            if(~isempty(region))
                for l = 1:height(obj.totalTable)
                    if(strcmp(obj.totalTable{l,3}, region))
                        match = [match;obj.totalTable(l,:)];
                    end 
                end 
            else
                match = obj.totalTable;
            end 

            varArray = [];
            %determines if scatter values are spaced by variable or not 
            if(~isempty(var))
                num = obj.getColumn(var);
                match = sortrows(match, num);
                for look = 1:height(match)
                    varArray = [varArray; match{look, num}];
                end 
            else 
                varArray = 1:height(match);
            end 

            %start for loop 
            for idx = 1:height(match)
                name = string(match{idx,1});
                current = match{idx,4};
                concs = cell2mat(current(:,7));
                loc = varArray(idx); 
                color = obj.getColor('Region', match{idx, 3});

                scatter(loc,concs,15,color);
                hold on
                errorbar(loc, mean(concs), std(concs), 'vertical','-ko', 'MarkerSize', 5, 'CapSize', 10, 'LineWidth',1.5, 'MarkerFaceColor', 'black');
                hold on 
                
                y = [y; mean(concs)];
                xt = [xt, loc];
                names = [names, name];
            end 
           
            %include lineFit or not 
            if(lineFit)
                Fit = polyfit(xt,y,2);
                plot(xt, polyval(Fit, xt), 'LineWidth', 4, 'Color', 'k')
            end 
            
            %title & legend formatting 
            if(~isempty(region))
                if(~isempty(var))
                    title("Concavity data by " + var + " for " + region)
                else 
                    title("Concavity data for " + region)
                end 
            else 
                lgd = obj.getLegend();
                if(~isempty(var))
                    title("Concavity data by " + var + " for all regions")
                else 
                    title("Concavity data for all regions")
                end 
            end 

            %figure & label formatting 
            ax1 = gca;
            if(isempty(var))
                var = "Islands, no order";
            end 
            xlabel(ax1, var)
            cap = xt(length(xt)) + xt(1);
            jump = round(cap, -1)/10; 
            xlim(ax1, [0 cap]);
            ylim(ax1, [-1,1]) 
            xticks(ax1, (0:jump:cap))

            ax2 = copyobj(ax1, gcf);
            ylabel(ax1, "SCI (Concavity Index)")
            set(ax2, 'Color', 'none', 'XAxisLocation', 'top', 'XTick', xt, 'XTickLabel', names);
            set(ax1, 'FontSize', 10);
            set(ax2, 'FontSize', 8);
            ax2.Position = ax1.Position;
            xtickangle(ax2,45);
            ax2.XLim = ax1.XLim;
            ax2.XLabel = [];    
            ax2.Title = [];
            ax2.YTickLabel = [];

            titlePosition = get(ax1.Title, 'Position');
            titlePosition(2) = titlePosition(2) + 0.1; 
            set(ax1.Title, 'Position', titlePosition);

        end 
        
        %plot the relationship between two variables (one can be concavity, 
        %other options depend on additional data in totalTable)  
        function varPlot = variablesPlot(obj, varargin)
            varPlot = figure();
            
            p = inputParser;
            addParameter(p, 'X', '');
            addParameter(p, 'Y', '');
            addOptional(p, 'Region', '');
            parse(p, varargin{:});
            x = p.Results.X;
            y = p.Results.Y;
            region = p.Results.Region;

            %set match based on if all regions or just one is being plotted
            match = cell(0,0);
            if(~isempty(region))
                for l = 1:height(obj.totalTable)
                    if(strcmp(obj.totalTable{l,3}, region))
                        match = [match;obj.totalTable(l,:)];
                    end 
                end 
            else
                match = obj.totalTable;
            end 
            
            %add column for mean concavity so that it's an available variable
            concCol = [];
            for go = 1:height(match)
                current = match{go,4};
                concs = cell2mat(current(:,7));
                concCol = [concCol; mean(concs)]; 
            end 
            concCol = num2cell(concCol);
            match = [match, concCol]; 
            match = sortrows(match, obj.getColumn(x)); 

            %plot the variables against eachother by looping through match     
            if(isempty(region))
                names = [];
                unqs = [];  
                for lookU = 1:height(match)
                    unqs = [unqs; match{lookU,3}];
                end 
                regs = unique(unqs);
                
                %plot each region as its own line 
                for l = 1:length(regs) 
                    xArray = [];
                    yArray = []; 
                    names = [];
                    for search = 1:height(match)
                        if(strcmp(match{search,3}, regs{l})) 
                            xArray = [xArray; match{search, obj.getColumn(x)}];
                            yArray = [yArray; match{search, obj.getColumn(y)}];
                            names = [names; string(match{search,1})];
                        end
                    end
                    color = obj.getColor('Region', regs{l});
                    plot(xArray, yArray,  '-o', 'Color', color, 'MarkerFaceColor', color, 'MarkerSize', 5, 'LineWidth', 2);
                    text(xArray, yArray, names, 'FontSize', 8, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
                    hold on 
                end 

            else
                xArray = [];
                yArray = []; 
                names = [];
                for look = 1:height(match)
                    xArray = [xArray; match{look, obj.getColumn(x)}];
                    yArray = [yArray; match{look, obj.getColumn(y)}];
                    names = [names; match{look, 1}];
                end 
                color = obj.getColor('Region', region);
                plot(xArray, yArray,  '-o', 'Color', color, 'MarkerFaceColor', color, 'MarkerSize', 5, 'LineWidth', 2);
                text(xArray, yArray, names, 'FontSize', 8, 'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom');
            end

            %title & plot formatting 
            if(~isempty(region))
                title(x + " and " + y + " for " + region)
            else 
                obj.getLegend()
                title(x + " and " + y + " for every region") 
            end 
            xlabel(x)
            ylabel(y)
            
        end 

        %output every rose & concavity figure for an island 
        function islandAll(obj, island)
            obj.getConcavity(island)
            obj.rosePlot(island)
            obj.normConcavityPlot(island)
            obj.spacialConcavityPlot(island)
            obj.normalizedRose(island)
        end 
        
        %output a complete concavityScatter & islandAll for every island in the project          
        function projectAll(obj)
            obj.concavityScatter(); %('Variable', 'age') suggested 
            for index = 1:height(obj.totalTable)
                curr = obj.totalTable{index,1};
                obj.islandAll(curr);
            end
        end 
    end
end