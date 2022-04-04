classdef ereef < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                      matlab.ui.Figure
        ControlPanel                  matlab.ui.container.Panel
        ScaleFactorCurrentsEditField  matlab.ui.control.NumericEditField
        ScaleFactorCurrentsEditFieldLabel  matlab.ui.control.Label
        ScaleFactorTempEditField      matlab.ui.control.NumericEditField
        ScaleFactorTempLabel          matlab.ui.control.Label
        AutoScaleCurrentsCheckBox     matlab.ui.control.CheckBox
        DataSourceURLEditField        matlab.ui.control.EditField
        DataSourceURLEditFieldLabel   matlab.ui.control.Label
        TimeDropDown                  matlab.ui.control.DropDown
        TimeDropDownLabel             matlab.ui.control.Label
        ElevationmDropDown            matlab.ui.control.DropDown
        ElevationmDropDownLabel       matlab.ui.control.Label
        ScaleTemperatureColourBarCheckBox  matlab.ui.control.CheckBox
        ShowCurrentsCheckBox          matlab.ui.control.CheckBox
        SelectLocationforTimeElevationTemperatureMapButton  matlab.ui.control.Button
        TemperaturePanel              matlab.ui.container.Panel
        MainPlot                      matlab.ui.control.UIAxes
        StatusLabel                   matlab.ui.control.Label
    end

    
    properties (Access = private)
        DATA % Description
        globalHandles
    end
    
    methods (Access = private)
        
        

        function getDataSourceInfo(app)
            %------------------------------------------------------------
            % Queries the OPeNDAP data source URL, determines the
            % dimensions of the variables to avoid hard-coding indices into
            % later data queries
            %------------------------------------------------------------
            
            % indicate to the user that the system is busy
            busyCursor(app)
            
            % use ncinfo to determine characteristics of data source. Exit
            % if there is connectivity or the URL is invalid
            try
                ginfo = ncinfo(app.DATA.sourceURL);
            catch
                err_dlg = errordlg('Could not contact OPeNDAP data source. No internet or invalid URL. Exiting','ERROR');
                waitfor(err_dlg); thisApp.delete;
            end

            % Only time is an unlimited variable
            unlimDims = [ginfo.Dimensions.Unlimited];
            disp(ginfo.Dimensions(unlimDims));
            
            % make sure the datasource has the var names expected
            try
                % get the indices for the X Y Z channels
                timeVar = strcmpi('time',{ginfo.Dimensions.Name});
                lonVar = strcmpi('i',{ginfo.Dimensions.Name});
                latVar = strcmpi('j',{ginfo.Dimensions.Name});
                zVar = strcmpi('k',{ginfo.Dimensions.Name});
            catch
                err_dlg = errordlg('Unexpected data structure','ERROR');
                waitfor(err_dlg); app.delete;
            end
            
            % store the dimensions of the data to be used for later queries
            app.DATA.dims.i = [ginfo.Dimensions(lonVar).Length];
            app.DATA.dims.j = [ginfo.Dimensions(latVar).Length];
            app.DATA.dims.k = [ginfo.Dimensions(zVar).Length];
            app.DATA.dims.time = [ginfo.Dimensions(timeVar).Length];
            app.DATA.dims.ji = [ginfo.Dimensions(latVar).Length ginfo.Dimensions(lonVar).Length];

            app.DATA.ginfo = ginfo;
            
            % indicate to the user that the system is ready
            readyCursor(app)
        end

        function retrieveFixedData(app)

            %------------------------------------------------------------
            % Pulls down the zc values (in metres), the dates/times of
            % available data, and the arrays of longitudes and latitudes
            %------------------------------------------------------------

            dataURL = app.DATA.sourceURL;
            
            % Hide Control Panel while data is downloaded
            app.ControlPanel.Visible = 'off';
            busyCursor(app)
            drawnow
            
            % retrieve dimensions of variables, subtracting 1 since
            % Matlab is base 1 and the data is originally base 0
            lonMax = num2str(app.DATA.dims.i - 1);
            latMax = num2str(app.DATA.dims.j - 1);
            zcMax = num2str(app.DATA.dims.k - 1);
            tMax = num2str(app.DATA.dims.time - 1);
            
            % retrieve data, throw error if no connectivity or bad URL
            try
                % getting depths
                q = ['zc[0:1:' zcMax '],time[0]'];
                app.DATA.depths = ncread([dataURL '?' q],'zc');
                
                % getting datetimes
                q=['zc[0],time[0:1:' tMax ']'];
                app.DATA.times = ncread([dataURL '?' q],'time');

                % clean up datetimes
                convertTimes(app)      
                
                % getting longitudes
                q = ['longitude[0:1:' latMax '][0:1:' lonMax ']'];
                app.DATA.lngs = ncread([dataURL '?' q],'longitude');

                % getting latitudes
                q = ['latitude[0:1:' latMax '][0:1:' lonMax ']'];
                app.DATA.lats = ncread([dataURL '?' q],'latitude');

           catch
                err_dlg = errordlg('Could not contact OPeNDAP data source. No internet or invalid URL. Exiting','ERROR');
                waitfor(err_dlg);  app.delete;
            end
            readyCursor(app)
        end
        
        function retriveVariableData(app)
            
            %------------------------------------------------------------
            % Pulls down all temperature data at a specific zc and specific
            % datetime.
            %------------------------------------------------------------

            % hide the control panel so that additional commands cannot be
            % sent while data is downloading. Make the pointer spin to
            % indicate that the GUI is not accessible

            app.ControlPanel.Visible = 'off';
            busyCursor(app);
            drawnow

            % if this is the first run, we choose the top zc to start with
            if app.ElevationmDropDown.Value == -1
                zc = app.DATA.dims.k - 1; 
            else
                zc = app.ElevationmDropDown.Value; % already base 0
            end

            % if this is the first run, we choose the first datetime
            % available
            if app.TimeDropDown.Value == -1
                t = 0;
            else
                t = app.TimeDropDown.Value; % already base 0
            end
            
            % download the temperatures for the entire region at a fixed
            % time and zc
            lonMax = num2str(app.DATA.dims.i - 1);
            latMax = num2str(app.DATA.dims.j - 1);

            % retrieve data, throw error if no connectivity or bad URL
            dataURL = app.DATA.sourceURL;
            try
                % getting temps at t=0...');
                q = ['temp[' num2str(t) '][' num2str(zc) '][0:1:' latMax '][0:1:' lonMax ']'];
                tmp = ncread([dataURL '?' q],'temp');
                app.DATA.temps = reshape(tmp,1,numel(tmp));
                
                % getting Us 
                q = ['u[' num2str(t) '][' num2str(zc) '][0:1:' latMax '][0:1:' lonMax ']'];
                tmp = ncread([dataURL '?' q],'u');
                app.DATA.U = reshape(tmp,1,numel(tmp));
                
                % getting Vs
                q = ['v[' num2str(t) '][' num2str(zc) '][0:1:' latMax '][0:1:' lonMax ']'];
                tmp = ncread([dataURL '?' q],'v');
                app.DATA.V = reshape(tmp,1,numel(tmp));
    
            catch
                err_dlg = errordlg('Could not contact OPeNDAP data source. No internet or invalid URL. Exiting','ERROR');
                waitfor(err_dlg);  app.delete;
            end
            readyCursor(app);
        end
        
       
        
        function populateDropDowns(app)

            %------------------------------------------------------------
            % Populates the zc and time drop-down menus with the retrieved
            % values
            %------------------------------------------------------------
                
            busyCursor(app)
            
            % populating zc dropdown
            for d=1:length(app.DATA.depths)
                dItems{length(app.DATA.depths) - d + 1} = num2str(app.DATA.depths(d));
                dItemsData{length(app.DATA.depths) - d + 1} = d-1;
            end
            app.ElevationmDropDown.Items = dItems;
            app.ElevationmDropDown.ItemsData = dItemsData;
            app.DATA.sDepths = dItems;

            % populating datetimes dropdown
            for t=1:length(app.DATA.ctimes)
                tItems(t) = string(app.DATA.ctimes(t));
                tItemsData{length(app.DATA.ctimes) - t + 1} = t-1;
            end
            app.TimeDropDown.Items = tItems;
            app.TimeDropDown.ItemsData = tItemsData;
            app.DATA.sTimes = tItems;
            
            readyCursor(app)
        end
        
        function convertTimes(app)

            %------------------------------------------------------------
            % Converts the time values from "days since midnight 1/1/1990"
            % into meaningful dates and times. Round up to the nearest hour
            %------------------------------------------------------------

            t0 = datetime(1990,1,1,0,0,0,'TimeZone','Australia/Brisbane');
            ctimes = t0 + app.DATA.times;
            ctimes = dateshift(ctimes,'start','hour','nearest');
            ctimes.Format = 'dd-MMM-uu HH:mm';
            app.DATA.ctimes = ctimes;
        end
        
        
    
        function plotTempCurrentMap(app)

            %------------------------------------------------------------
            % Plots the temperature map on top of a (modified) map borrowed
            % the eReefs website. Also can plot the current arrows as an
            % option. Temperature colour bar can be static (default) or dynamic
            % (maximise contrast)
            %------------------------------------------------------------
            
            % disable control panel while drawing new map
            app.ControlPanel.Visible = 'off';
            busyCursor(app)
            drawnow
            disableDefaultInteractivity(app.MainPlot)

            % remove invalid entries, temperatures that are too high and
            % might be anomalous (indices = R)
            % TODO: allow user to set this option
            R = find(app.DATA.temps < 60);
            
            % reshape longitudes and latitudes into 1D arrays for easier
            % manipulation, remove coords with invalid temperatures (R)
            tmp = reshape(app.DATA.lats,1,numel(app.DATA.lats));
            lats_Txs = tmp(R);
            tmp = reshape(app.DATA.lngs,1,numel(app.DATA.lngs));
            lngs_Txs = tmp(R);
            clear tmp
            
            % remove temperature and u,v current values with invalid
            % temperatures (R)
            temps_Txs = app.DATA.temps(R);
            u_Txs = app.DATA.U(R);
            v_Txs = app.DATA.V(R);

            %fprintf('min temp = %1.4f, max = %1.4f\n',min(temps_Txs),max(temps_Txs))
            
            % load created geotiff of map borrowed from the eReef website.
            % If mapping toolbox not installed, will catch:
            try
                g = geoshow(app.MainPlot, 'reefmap.tif');
                % Set the coordinates based on the geotiff:
                app.MainPlot.XLim = [min(g.XData(:)) max(g.XData(:))];
                app.MainPlot.YLim = [min(g.YData(:)) max(g.YData(:))];
            catch
                % if mapping toolbox not available, make do:
                err_dlg = errordlg('Is the Matlab Mapping toolbox available? ','Warning');
                waitfor(err_dlg);
                app.MainPlot.XLim = [142.2860  156.4540];
                app.MainPlot.YLim = [-29.4780 -7.3860   ];
                set(app.MainPlot, 'YDir','normal')
                % if reefmap.tif not found, will not load background map
                if isfile('reefmap.tif')
                    img = flipud(imread('reefmap.tif'));
                    imagesc(app.MainPlot, app.MainPlot.XLim, app.MainPlot.YLim, img);
                else
                    err_dlg = errordlg('reefmap.tif not in path','ERROR');
                    waitfor(err_dlg);
                end
                set(app.MainPlot, 'YDir','normal')
                %waitfor(err_dlg);              
            end
            hold(app.MainPlot,'on');

            % plot a portion (every nth value) of the temperatures
            n = app.ScaleFactorTempEditField.Value;
            scatter(app.MainPlot,lngs_Txs(1:n:end), lats_Txs(1:n:end),10, temps_Txs(1:n:end),'filled');
            hold(app.MainPlot,'on');
         
            
            % create a colorbar, either scale it for maximal contrast with
            % the range of temperatures encountered, or keep it static
            % (static is default)
            % TODO: allow user to set the default range
            colorbar(app.MainPlot);
            if app.ScaleTemperatureColourBarCheckBox.Value == 0
                caxis(app.MainPlot,[0 45]);
            else
                caxis(app.MainPlot,[min(temps_Txs) max(temps_Txs)]);
            end

            % plot a portion (every nth value) of the u,v currents
            n = app.ScaleFactorCurrentsEditField.Value;

            %app.globalHandles.q = quiver(app.MainPlot,lngs_Txs(1:n:end), lats_Txs(1:n:end), u_Txs(1:n:end), v_Txs(1:n:end),'color',[0,0,0]); 
            if app.AutoScaleCurrentsCheckBox.Value == 1, autoScale = 'on'; else, autoScale = 'off'; end
            app.globalHandles.q = quiver(app.MainPlot,lngs_Txs(1:n:end), lats_Txs(1:n:end), u_Txs(1:n:end), v_Txs(1:n:end),'color',[0,0,0],'AutoScale',autoScale); 
            
            % add a legend for the u,v currents to indicate scale
            app.globalHandles.qLeg1 = rectangle(app.MainPlot, 'Position',[143 -29 4 2]);
            app.globalHandles.qLeg1.FaceColor = [1 1 1];
            app.globalHandles.qLeg2 = quiver(app.MainPlot, 143.5, -28.5, 0, 1,'color',[0,0,0],'AutoScale',autoScale,'MaxHeadSize',1);
            app.globalHandles.qLeg3 = text(app.MainPlot,144,-28,'Scale = 1m/s');

            % allow the current arrows and legend to be switched on or off.
            if app.ShowCurrentsCheckBox.Value == 1 
                set(app.globalHandles.q,'Visible','on');
                % if the currents are autoscaled, the scale is meaningless
                % so switch it off
                if app.AutoScaleCurrentsCheckBox.Value == 0
                    set(app.globalHandles.qLeg1,'Visible','on');
                    set(app.globalHandles.qLeg2,'Visible','on');
                    set(app.globalHandles.qLeg3,'Visible','on');
                else
                    set(app.globalHandles.qLeg1,'Visible','off');
                    set(app.globalHandles.qLeg2,'Visible','off');
                    set(app.globalHandles.qLeg3,'Visible','off');
                end
            else
                set(app.globalHandles.q,'Visible','off');
                set(app.globalHandles.qLeg1,'Visible','off');
                set(app.globalHandles.qLeg2,'Visible','off');
                set(app.globalHandles.qLeg3,'Visible','off');
            end
            hold(app.MainPlot,'off');
            
            % everything has been drawn now, can switch on the control
            % panel and the completed map panel
            app.ControlPanel.Visible = 'on';
            app.TemperaturePanel.Visible = 'on';
            %datacursormode(app.UIFigure)
            readyCursor(app);
            drawnow
        end
        
        function createTimeTempArray(app)

            %------------------------------------------------------------
            % Creates a temperature array wrt datetime and depth
            % Currently requires Matlab version 2020b or above
            %------------------------------------------------------------

            % if there was a previous coordinate selection made, remove it
            try delete(app.globalHandles.coordSelection); catch, end
            
            % give user cross-hairs to pick coords
            app.UIFigure.HandleVisibility = 'callback'; 
            x = ginput(1);
   
            
            busyCursor(app);
            % find the closest match for the selected coordinates
            L = abs(app.DATA.lngs - x(1)) + abs(app.DATA.lats - x(2));
            [x1,y1] = find(L==min(L(:)));
            selectionError = min(L(:));
            

            % if the point clicked is more than 0.2 degrees away from a
            % known long/lat, do not continue
            if selectionError < 0.2
                app.DATA.selectionCoords = [x1 y1];

                % put a red asterisk at the coordinates (if valid)
                hold(app.MainPlot,'on');
                app.globalHandles.coordSelection = plot(app.MainPlot,x(1),x(2),'r*');
                drawnow
                hold(app.MainPlot,'off');
                
                % create a title for the plot from the coordinates
                str = ['Longitude = ' num2str(app.DATA.lngs(x1,y1)) ', Latitude = ' num2str(app.DATA.lats(x1,y1)) ];
                app.DATA.selectionText = str;

                % retrieve the data and plot the data in a new window
                retrieveTimeTempArray(app);
                plotTimeTempArray(app)
            else
                err_dlg = errordlg('Selection is greater than 0.2 degrees from available data','ERROR');
                waitfor(err_dlg); 
            end
            readyCursor(app);
        end

        
        function retrieveTimeTempArray(app)

            %------------------------------------------------------------
            % Called by coordinate selector. Downloads 2D time/zc
            % temperature map
            % Currently requires Matlab version 2020b or above
            %------------------------------------------------------------

            dataURL = app.DATA.sourceURL;
            
            % get longitude and latitude selected by user, correct for base
            % 0 vs base 1
            c = app.DATA.selectionCoords - 1
            
            % select full range of times and zc
            tMax = num2str(app.DATA.dims.time - 1);
            zcMax = num2str(app.DATA.dims.k - 1);

            q = ['temp[0:1:' tMax '][0:1:' zcMax '][' num2str(c(2)) '][' num2str(c(1)) ']'];
            try
                app.DATA.timeTemp = squeeze(ncread([dataURL '?' q],'temp'));
                % remote anomalous temps and temps = 1.0E35 and replace with
                % NaN:
                app.DATA.timeTemp(find(app.DATA.timeTemp > 60)) = NaN;
            catch
                err_dlg = errordlg('Could not contact OPeNDAP data source. No internet or invalid URL. Exiting','ERROR');
                waitfor(err_dlg);  app.delete;
            end
               
        end
     
        
        
        function plotTimeTempArray(app)
            
            %------------------------------------------------------------
            % Spawns a new figure that displays temperature at a
            % preselected longitude/latitude with respect to time (x axis)
            % and elevation (zc, y axis)
            % Currently requires Matlab version 2020b or above
            %------------------------------------------------------------

            function modDataTip(h,xlabel,ylabel)
                %------------------------------------------------------------
                % Creates a datatip for displaying temp at depth/time
                %------------------------------------------------------------
                % create template
                dt = datatip(h,h.XData(1),h.YData(1),'Visible','off'); 
                
                % get the indices for the X Y Z channels
                ix = strcmpi('X',{h.DataTipTemplate.DataTipRows.Label});
                iy = strcmpi('Y',{h.DataTipTemplate.DataTipRows.Label});
                iz = strcmpi('Z',{h.DataTipTemplate.DataTipRows.Label});
                
                % populate the datatip with time, elevation, temperature
                X = strings(length(ylabel),length(xlabel));
                for k=1:length(ylabel), X(k,:) = xlabel(1,:); end
                timeData = dataTipTextRow('Time',X);
                elevData = dataTipTextRow('Elev',flipud(ones(1,length(xlabel)).*str2double(ylabel)'));
                tempData = dataTipTextRow('Temp',h.CData);
                
                h.DataTipTemplate.DataTipRows(ix) = timeData;
                h.DataTipTemplate.DataTipRows(iy) = elevData;
                h.DataTipTemplate.DataTipRows(iz) = tempData;

                % Remove datatip template
                delete(dt)
            end

            % Create XTickLabels
            % ticks every 4th datetime, make sure 1st and last are included
            ts = 1:4:length(app.DATA.sTimes);
            if ts(end) ~= length(app.DATA.sTimes)
                ts = [ts length(app.DATA.sTimes)];
            end
            c=0;
            for i = ts
                c = c + 1; 
                newXTickLabel{c} = app.DATA.sTimes(i); 
            end
            
            % Create YTickLabels
            sdf = flip(app.DATA.sDepths);
            c=0;
            % ticks every 4th depth, make sure 1st and last are included
            ds = 1:4:length(app.DATA.sDepths);
            if ds(end) ~= length(app.DATA.sDepths)
                ds = [ds length(app.DATA.sDepths)];
            end
            for i = ds
                c = c + 1; 
                newYTickLabel{c} = sdf{i}; 
            end
            
            % do pcolor plot in new window
            hf = figure;
            hc = hf;

            % collect the handles of the spawned figures so we can close
            % them when we close the app
            nf = length(app.globalHandles.spawned);
            app.globalHandles.spawned(nf+1).handle = hc;

            % create the figure
            set(hf, 'MenuBar', 'none');
            set(hf, 'ToolBar', 'none');
            hf = gca;
            cmap = [1 1 1; parula(30)];
            colorbar(hf)
            colormap(cmap)
            hP = pcolor(double(app.DATA.timeTemp));
            hF = gca;
            hF.XTick = ts;
            hF.XTickLabel = newXTickLabel;
            hF.YTick = ds;
            hF.YTickLabel = newYTickLabel;
            hF.Title.String = app.DATA.selectionText;
            hF.YLabel.String = 'Elevation (m)';
            hF.XLabel.String = '';
            
            % allow user to click on figure to view individual data points
            colorbar
            modDataTip(hP,app.DATA.sTimes,app.DATA.sDepths)
            datacursormode(hc,'on')
            datatip(hP,0.75,0);
            
            % clean up
            set(gca,'FontSize',8);

        end
    
        function busyCursor(app)
            %------------------------------------------------------------
            % Indicates to the user that the program is busy
            %------------------------------------------------------------
            
            % this does not work in earlier versions of Matlab:
            try set(app.UIFigure, 'Pointer','watch'); catch, end
            % this is an alternative for earlier versions of Matlab:
            app.globalHandles.progress = uiprogressdlg(app.UIFigure,'Title','Working');
            app.globalHandles.progress.Indeterminate = 'on';
        end
    
        function readyCursor(app)
            %------------------------------------------------------------
            % Indicates to the user that the program is now ready
            %------------------------------------------------------------
            try 
                % this does not work in earlier versions of Matlab:
                set(app.UIFigure, 'Pointer','arrow'); 
            catch
                app.globalHandles.progress.delete();
            end
            % if the dialogue exists, delete it
            try app.globalHandles.progress.delete(); catch, end
        end
    end
    

    % Callbacks that handle component events
    methods (Access = private)

        % Code that executes after component creation
        function startupFcn(app)
            
            % start GUI in top left corner
            movegui(app.UIFigure,'northwest');
            
            % indicate to the user that the system is busy
            %app.ControlPanel.Visible = 'off'
            %app.TemperaturePanel.Visible = 'off';
            busyCursor(app);
            drawnow

            % create a repository of handles for new figures
            app.globalHandles.spawned = [];
            
            % set the default datasource URL:
            app.DATA.sourceURL = 'https://dapds00.nci.org.au/thredds/dodsC/fx3/gbr1_2.0/gbr1_simple_2022-03-11.nc';
            app.DataSourceURLEditField.Value = app.DATA.sourceURL;

            % query the datasource to gather information and check
            % integrity
            getDataSourceInfo(app);
            
            % label the axes
            app.MainPlot.Title.String = '';
            app.MainPlot.XLabel.String = 'Longitude';
            app.MainPlot.YLabel.String = 'Latitude';
            
            % download data and update the user on progress
            app.TemperaturePanel.Title = 'Retrieving fixed data from server...';
            drawnow;
            retrieveFixedData(app);
            app.TemperaturePanel.Title = 'Retrieving variable data from server...';
            drawnow;
            retriveVariableData(app);
            app.TemperaturePanel.Title = 'Temperature';
            drawnow;
            
            % convert the times into usable entities
            convertTimes(app);

            % populate the dropdowns with the depths and times:
            populateDropDowns(app);
            
            % plot the temperature map
            plotTempCurrentMap(app);
            readyCursor(app)
        end

        % Value changed function: DataSourceURLEditField
        function DataSourceURLEditFieldValueChanged(app, event)
            %-------------------------------------------------------------
            % function to load new data if the source URL is changed and is
            % valid
            %-------------------------------------------------------------
            
            prevURL = app.DATA.sourceURL;
            value = app.DataSourceURLEditField.Value;
            try
                app.DATA.sourceURL = value;
                getDataSourceInfo(app);
                app.TemperaturePanel.Title = 'Loading new values for new Data Source...';
                drawnow
            catch
                err_dlg = errordlg('URL is not valid, returning to previous URL','ERROR');
                waitfor(err_dlg);
                app.DATA.sourceURL = prevURL;
                app.DataSourceURLEditField.Value = prevURL;
                getDataSourceInfo(app);
            end
            retrieveFixedData(app)
            retriveVariableData(app)
            convertTimes(app);
            populateDropDowns(app);
            plotTempCurrentMap(app);

            app.TemperaturePanel.Title = 'Temperature';
            drawnow
        end

        % Value changed function: ElevationmDropDown
        function ElevationmDropDownValueChanged(app, event)
            %value = app.ElevationmDropDown.Value;
            app.TemperaturePanel.Title = 'Loading new values for new Depth selection...';
            drawnow
            retriveVariableData(app)
            plotTempCurrentMap(app)
            app.TemperaturePanel.Title = 'Temperature';
        end

        % Value changed function: TimeDropDown
        function TimeDropDownValueChanged(app, event)
            %value = app.TimeDropDown.Value;
            app.TemperaturePanel.Title = 'Loading new values for new Time selection...';
            drawnow
            retriveVariableData(app)
            plotTempCurrentMap(app)
            app.TemperaturePanel.Title = 'Temperature';
        end

        % Button pushed function: 
        % SelectLocationforTimeElevationTemperatureMapButton
        function SelectLocationforTimeElevationTemperatureMapButtonPushed(app, event)
            if verLessThan('Matlab', '9.9')
                err_dlg = errordlg('Not supported prior to Matlab R2020b');
                waitfor(err_dlg);
            else
                createTimeTempArray(app)
            end
        end

        % Value changed function: ScaleTemperatureColourBarCheckBox
        function ScaleTemperatureColourBarCheckBoxValueChanged(app, event)
            %value = app.ScaleTemperatureColourBarCheckBox.Value;
            plotTempCurrentMap(app)
        end

        % Value changed function: ShowCurrentsCheckBox
        function ShowCurrentsCheckBoxValueChanged(app, event)
            % Toggle on/off currents
            if app.ShowCurrentsCheckBox.Value == 1 
                set(app.globalHandles.q,'Visible','on');
                % if the currents are autoscaled, the scale is meaningless
                % so switch it off
                if app.AutoScaleCurrentsCheckBox.Value == 0
                    set(app.globalHandles.qLeg1,'Visible','on');
                    set(app.globalHandles.qLeg2,'Visible','on');
                    set(app.globalHandles.qLeg3,'Visible','on');
                else
                    set(app.globalHandles.qLeg1,'Visible','off');
                    set(app.globalHandles.qLeg2,'Visible','off');
                    set(app.globalHandles.qLeg3,'Visible','off');
                end
            else
                set(app.globalHandles.q,'Visible','off');
                set(app.globalHandles.qLeg1,'Visible','off');
                set(app.globalHandles.qLeg2,'Visible','off');
                set(app.globalHandles.qLeg3,'Visible','off');
            end
        end

        % Value changed function: AutoScaleCurrentsCheckBox
        function AutoScaleCurrentsCheckBoxValueChanged(app, event)
            plotTempCurrentMap(app);
            
        end

        % Value changed function: ScaleFactorTempEditField
        function ScaleFactorTempEditFieldValueChanged(app, event)
            plotTempCurrentMap(app);

        end

        % Value changed function: ScaleFactorCurrentsEditField
        function ScaleFactorCurrentsEditFieldValueChanged(app, event)
            plotTempCurrentMap(app);
            
        end

        % Close request function: UIFigure
        function UIFigureCloseRequest(app, event)
            % first close any figures we created
            for i = 1:length(app.globalHandles.spawned)
                try close(app.globalHandles.spawned(i).handle); catch, end
            end
            delete(app)
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [50 50 809 717];
            app.UIFigure.Name = 'eReef';
            app.UIFigure.CloseRequestFcn = createCallbackFcn(app, @UIFigureCloseRequest, true);

            % Create StatusLabel
            app.StatusLabel = uilabel(app.UIFigure);
            app.StatusLabel.HorizontalAlignment = 'center';
            app.StatusLabel.FontSize = 14;
            app.StatusLabel.FontWeight = 'bold';
            app.StatusLabel.FontColor = [0.3922 0.8314 0.0745];
            app.StatusLabel.Position = [5 673 237 42];
            app.StatusLabel.Text = 'Retrieving data, please wait';

            % Create TemperaturePanel
            app.TemperaturePanel = uipanel(app.UIFigure);
            app.TemperaturePanel.Title = 'Temperature';
            app.TemperaturePanel.Position = [272 13 525 692];

            % Create MainPlot
            app.MainPlot = uiaxes(app.TemperaturePanel);
            title(app.MainPlot, 'Title')
            xlabel(app.MainPlot, 'X')
            ylabel(app.MainPlot, 'Y')
            zlabel(app.MainPlot, 'Z')
            app.MainPlot.Position = [10 12 506 649];

            % Create ControlPanel
            app.ControlPanel = uipanel(app.UIFigure);
            app.ControlPanel.Position = [15 289 251 416];

            % Create SelectLocationforTimeElevationTemperatureMapButton
            app.SelectLocationforTimeElevationTemperatureMapButton = uibutton(app.ControlPanel, 'push');
            app.SelectLocationforTimeElevationTemperatureMapButton.ButtonPushedFcn = createCallbackFcn(app, @SelectLocationforTimeElevationTemperatureMapButtonPushed, true);
            app.SelectLocationforTimeElevationTemperatureMapButton.Position = [13 165 214 38];
            app.SelectLocationforTimeElevationTemperatureMapButton.Text = {'Select Location for '; 'Time/Elevation Temperature Map'};

            % Create ShowCurrentsCheckBox
            app.ShowCurrentsCheckBox = uicheckbox(app.ControlPanel);
            app.ShowCurrentsCheckBox.ValueChangedFcn = createCallbackFcn(app, @ShowCurrentsCheckBoxValueChanged, true);
            app.ShowCurrentsCheckBox.Text = 'Show Currents';
            app.ShowCurrentsCheckBox.Position = [17 227 101 22];
            app.ShowCurrentsCheckBox.Value = true;

            % Create ScaleTemperatureColourBarCheckBox
            app.ScaleTemperatureColourBarCheckBox = uicheckbox(app.ControlPanel);
            app.ScaleTemperatureColourBarCheckBox.ValueChangedFcn = createCallbackFcn(app, @ScaleTemperatureColourBarCheckBoxValueChanged, true);
            app.ScaleTemperatureColourBarCheckBox.Text = 'Scale Temperature Colour Bar';
            app.ScaleTemperatureColourBarCheckBox.Position = [15 278 183 23];

            % Create ElevationmDropDownLabel
            app.ElevationmDropDownLabel = uilabel(app.ControlPanel);
            app.ElevationmDropDownLabel.HorizontalAlignment = 'right';
            app.ElevationmDropDownLabel.Position = [12 347 76 22];
            app.ElevationmDropDownLabel.Text = 'Elevation (m)';

            % Create ElevationmDropDown
            app.ElevationmDropDown = uidropdown(app.ControlPanel);
            app.ElevationmDropDown.Items = {'-'};
            app.ElevationmDropDown.ItemsData = -1;
            app.ElevationmDropDown.ValueChangedFcn = createCallbackFcn(app, @ElevationmDropDownValueChanged, true);
            app.ElevationmDropDown.Position = [103 347 100 22];
            app.ElevationmDropDown.Value = -1;

            % Create TimeDropDownLabel
            app.TimeDropDownLabel = uilabel(app.ControlPanel);
            app.TimeDropDownLabel.HorizontalAlignment = 'right';
            app.TimeDropDownLabel.Position = [16 310 31 22];
            app.TimeDropDownLabel.Text = 'Time';

            % Create TimeDropDown
            app.TimeDropDown = uidropdown(app.ControlPanel);
            app.TimeDropDown.Items = {'-'};
            app.TimeDropDown.ItemsData = -1;
            app.TimeDropDown.ValueChangedFcn = createCallbackFcn(app, @TimeDropDownValueChanged, true);
            app.TimeDropDown.Position = [62 310 178 22];
            app.TimeDropDown.Value = -1;

            % Create DataSourceURLEditFieldLabel
            app.DataSourceURLEditFieldLabel = uilabel(app.ControlPanel);
            app.DataSourceURLEditFieldLabel.HorizontalAlignment = 'right';
            app.DataSourceURLEditFieldLabel.Position = [12 383 99 22];
            app.DataSourceURLEditFieldLabel.Text = 'Data Source URL';

            % Create DataSourceURLEditField
            app.DataSourceURLEditField = uieditfield(app.ControlPanel, 'text');
            app.DataSourceURLEditField.ValueChangedFcn = createCallbackFcn(app, @DataSourceURLEditFieldValueChanged, true);
            app.DataSourceURLEditField.Position = [126 383 113 21];

            % Create AutoScaleCurrentsCheckBox
            app.AutoScaleCurrentsCheckBox = uicheckbox(app.ControlPanel);
            app.AutoScaleCurrentsCheckBox.ValueChangedFcn = createCallbackFcn(app, @AutoScaleCurrentsCheckBoxValueChanged, true);
            app.AutoScaleCurrentsCheckBox.Text = 'Autoscale Currents';
            app.AutoScaleCurrentsCheckBox.Position = [122 227 124 22];

            % Create ScaleFactorTempLabel
            app.ScaleFactorTempLabel = uilabel(app.ControlPanel);
            app.ScaleFactorTempLabel.HorizontalAlignment = 'right';
            app.ScaleFactorTempLabel.Position = [42 49 105 22];
            app.ScaleFactorTempLabel.Text = 'Scale Factor Temp';

            % Create ScaleFactorTempEditField
            app.ScaleFactorTempEditField = uieditfield(app.ControlPanel, 'numeric');
            app.ScaleFactorTempEditField.Limits = [1 5000];
            app.ScaleFactorTempEditField.ValueChangedFcn = createCallbackFcn(app, @ScaleFactorTempEditFieldValueChanged, true);
            app.ScaleFactorTempEditField.Position = [169 49 49 23];
            app.ScaleFactorTempEditField.Value = 1;

            % Create ScaleFactorCurrentsEditFieldLabel
            app.ScaleFactorCurrentsEditFieldLabel = uilabel(app.ControlPanel);
            app.ScaleFactorCurrentsEditFieldLabel.HorizontalAlignment = 'right';
            app.ScaleFactorCurrentsEditFieldLabel.Position = [32 12 122 22];
            app.ScaleFactorCurrentsEditFieldLabel.Text = 'Scale Factor Currents';

            % Create ScaleFactorCurrentsEditField
            app.ScaleFactorCurrentsEditField = uieditfield(app.ControlPanel, 'numeric');
            app.ScaleFactorCurrentsEditField.Limits = [1 5000];
            app.ScaleFactorCurrentsEditField.ValueChangedFcn = createCallbackFcn(app, @ScaleFactorCurrentsEditFieldValueChanged, true);
            app.ScaleFactorCurrentsEditField.Position = [169 12 49 22];
            app.ScaleFactorCurrentsEditField.Value = 1000;

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = ereef

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            % Execute the startup function
            runStartupFcn(app, @startupFcn)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end