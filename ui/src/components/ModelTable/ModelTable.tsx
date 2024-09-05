import GenerateTable from '@/components/Table/Table';
import { getAllModels, APIData } from '@/services/models';
import { addIconDataToArray, ConvertToTableData } from '@/utils';
import NoModels from '@/views/Models/NoModels';
import Loader from '@/components/Loader';
import useQueryWrapper from '@/hooks/useQueryWrapper';
import { useStore } from '@/stores';

type ModelTableProps = {
  handleOnRowClick: (args: unknown) => void;
};

const ModelTable = ({ handleOnRowClick }: ModelTableProps): JSX.Element => {
  const activeWorkspaceId = useStore((state) => state.workspaceId);

  const { data } = useQueryWrapper<APIData, Error>(
    ['models', activeWorkspaceId],
    () => getAllModels({ type: 'data' }),
    {
      refetchOnMount: true,
      refetchOnWindowFocus: false,
    },
  );

  const models = data?.data;

  if (!models) {
    return <Loader />;
  }

  if (models.length === 0) return <NoModels />;

  const values = ConvertToTableData(addIconDataToArray(models), [
    { name: 'Name', key: 'name', showIcon: true },
    { name: 'Query Type', key: 'query_type' },
    { name: 'Updated At', key: 'updated_at' },
  ]);

  return (
    <GenerateTable
      data={values}
      headerColorVisible={true}
      onRowClick={handleOnRowClick}
      maxHeight='2xl'
    />
  );
};

export default ModelTable;
