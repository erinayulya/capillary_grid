function A = readAreaMatrix(filePath)
%READAREAMATRIX Read one area matrix in m^2 from Excel or a numeric .m file.
% Excel: first sheet, numeric cells only, no headings. M file: one bracketed
% numeric matrix, optionally assigned to a variable; comments and ... allowed.
% The M file is parsed as data and is never executed.
if ~isfile(filePath)
    error('readAreaMatrix:MissingFile','Файл не найден: %s',filePath);
end
[~,~,extension] = fileparts(filePath);
switch lower(extension)
    case {'.xlsx','.xls'}
        cells = readcell(filePath,'Sheet',1);
        numericCells = cellfun(@(x) isnumeric(x) && isscalar(x) && isreal(x),cells);
        if isempty(cells) || ~all(numericCells(:))
            error('readAreaMatrix:ExcelFormat', ...
                'На первом листе должны быть только числа: без заголовков и пустых ячеек внутри матрицы.');
        end
        A = cell2mat(cells);
    case '.m'
        text = fileread(filePath);
        text = strrep(text,char(65279),''); % Optional UTF-8 BOM.
        text = regexprep(text,'%[^\r\n]*','');
        text = regexprep(text,'\.\.\.[ \t]*\r?\n',' ');
        body = regexp(text, ...
            '^\s*(?:[A-Za-z]\w*\s*=\s*)?\[([\s\S]*)\]\s*;?\s*$', ...
            'tokens','once');
        if isempty(body)
            error('readAreaMatrix:MFormat', ...
                'В .m-файле нужна одна числовая матрица, например A = [1e-8 2e-8; 3e-8 4e-8];');
        end
        rows = regexp(strtrim(body{1}),';|\r\n|\n|\r','split');
        rows = rows(~cellfun(@(x) isempty(strtrim(x)),rows));
        number = '[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eEdD][+-]?\d+)?';
        rowPattern = ['^\s*' number '(?:(?:\s*,\s*|\s+)' number ')*\s*$'];
        values = cell(size(rows));
        for rowIndex = 1:numel(rows)
            if isempty(regexp(rows{rowIndex},rowPattern,'once'))
                error('readAreaMatrix:MFormat', ...
                    'В .m-файле разрешены только числа, пробелы, запятые и разделители строк; выражения и команды не выполняются.');
            end
            tokens = regexp(rows{rowIndex},number,'match');
            values{rowIndex} = str2double(regexprep(tokens,'[dD]','e'));
        end
        if isempty(values) || numel(unique(cellfun(@numel,values))) ~= 1
            error('readAreaMatrix:MFormat','Все строки матрицы должны содержать одинаковое число элементов.');
        end
        A = vertcat(values{:});
    otherwise
        error('readAreaMatrix:Extension','Выберите Excel (.xlsx, .xls) или числовую матрицу .m.');
end
validateattributes(A,{'numeric'},{'real','2d','nonempty','finite','positive'}, ...
    mfilename,'A');
end
