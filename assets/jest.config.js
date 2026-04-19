module.exports = {
  testEnvironment: 'jsdom',
  roots: ['<rootDir>/js/tests'],
  transform: {
    '^.+\\.(js|jsx)$': 'babel-jest',
  },
  transformIgnorePatterns: [
    'node_modules/(?!(marked|dompurify|marked-katex-extension|katex|@codemirror|@uiw|codemirror-lang-elixir)/)',
  ],
  moduleNameMapper: {
    '^@/(.*)$': '<rootDir>/js/$1',
    '^phoenix$': '<rootDir>/js/__mocks__/phoenix.js',
    '^@uiw/react-codemirror$': '<rootDir>/js/__mocks__/codemirror.js',
    '^@codemirror/lang-(.*)$': '<rootDir>/js/__mocks__/lang.js',
    '^@codemirror/legacy-modes/(.*)$': '<rootDir>/js/__mocks__/legacy.js',
    '^@codemirror/language-data$': '<rootDir>/js/__mocks__/lang.js',
    '^@codemirror/(.*)$': '<rootDir>/js/__mocks__/codemirror.js',
    '^codemirror-lang-elixir$': '<rootDir>/js/__mocks__/lang.js',
    '^marked$': '<rootDir>/js/__mocks__/marked.js',
    '^marked-katex-extension$': '<rootDir>/js/__mocks__/marked-katex.js',
    '^dompurify$': '<rootDir>/js/__mocks__/dompurify.js',
    '^katex$': '<rootDir>/js/__mocks__/katex.js',
  },
  moduleFileExtensions: ['js', 'jsx', 'json'],
  testMatch: ['**/*.test.js', '**/*.test.jsx'],
};