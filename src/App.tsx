import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { Layout } from "./components/Layout";
import { ImportPage } from "./pages/ImportPage";
import { InvalidImportPage } from "./pages/InvalidImportPage";
import { ManualCorrectionPage } from "./pages/ManualCorrectionPage";
import { MonthPage } from "./pages/MonthPage";
import { SettingsPage } from "./pages/SettingsPage";
import { TodayPage } from "./pages/TodayPage";
import { WeekPage } from "./pages/WeekPage";

export default function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/today" replace />} />
        <Route path="/import" element={<ImportPage />} />
        <Route path="/invalid-import" element={<InvalidImportPage />} />
        <Route path="/correct-import" element={<ManualCorrectionPage />} />
        <Route element={<Layout />}>
          <Route path="/today" element={<TodayPage />} />
          <Route path="/week" element={<WeekPage />} />
          <Route path="/month" element={<MonthPage />} />
          <Route path="/settings" element={<SettingsPage />} />
        </Route>
        <Route path="*" element={<Navigate to="/today" replace />} />
      </Routes>
    </BrowserRouter>
  );
}
