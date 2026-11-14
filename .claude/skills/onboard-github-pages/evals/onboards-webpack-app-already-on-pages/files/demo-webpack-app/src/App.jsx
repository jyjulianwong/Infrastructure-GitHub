import { BrowserRouter } from "react-router-dom";
export default function App() {
  return <BrowserRouter basename={process.env.ROUTER_BASENAME || ""}>Hi</BrowserRouter>;
}
