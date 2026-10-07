% Проверка сохранённых расчётов. Запускать из папки tests: runTests
% По умолчанию проверяются все папки запусков в results.
% Для одного расчёта укажите его полный путь в resultsTarget.
testsDirectory = fileparts(mfilename('fullpath'));
resultsTarget = fullfile(fileparts(testsDirectory), 'results');
% resultsTarget = fullfile(fileparts(testsDirectory), 'results', 'run_...');
testSummary = checkResults(resultsTarget);
disp(struct2table(testSummary));
