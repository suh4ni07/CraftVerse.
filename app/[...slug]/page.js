import Store from '../store';
export default async function Page({ params }) { const { slug = [] } = await params; return <Store page={slug.join('/')} />; }
