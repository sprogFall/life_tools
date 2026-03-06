import { OverviewPage } from '@/components/overview-page';
import { fetchDashboardUsers } from '@/lib/api';

export default async function HomePage() {
  const users = await fetchDashboardUsers();
  return <OverviewPage users={users} />;
}
