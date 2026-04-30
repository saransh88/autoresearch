// Example Stryker config for mutation testing with Jest
// Scope it to the modules you care about — don't run on everything at once

export default {
  testRunner: 'jest',
  jest: {
    projectType: 'create-react-app',
    enableFindRelatedTests: false,
    config: {
      resetMocks: false,
      testMatch: [
        '<rootDir>/src/tests/modules/**/*.test.js',
      ],
    },
  },
  coverageAnalysis: 'off',   // runs all tests per mutant — slower but more accurate
  mutate: [
    'src/modules/**/*.js',   // source files to mutate — not the tests
  ],
  reporters: ['html', 'progress', 'clear-text'],
  htmlReporter: { fileName: 'mutation-report.html' },
  timeoutMS: 30000,
  timeoutFactor: 2,
  concurrency: 4,
};
