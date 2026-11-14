const path = require("path");
const { EnvironmentPlugin } = require("webpack");
const HtmlWebpackPlugin = require("html-webpack-plugin");
const CopyPlugin = require("copy-webpack-plugin");

const envVars = { ROUTER_BASENAME: null };

module.exports = {
  entry: path.resolve(__dirname, "../src/index.jsx"),
  plugins: [
    new EnvironmentPlugin(envVars),
    new HtmlWebpackPlugin({ template: path.resolve(__dirname, "../src/index.html") }),
    new CopyPlugin({
      patterns: [
        { from: path.resolve(__dirname, "../src/favicon.ico") },
      ],
    }),
  ],
  output: { publicPath: "/", path: path.resolve(__dirname, "../dist"), filename: "main.js", clean: true },
};
