import { connect } from 'react-redux';
<<<<<<< HEAD
import { changeColumnParams } from 'flavours/glitch/actions/columns';
import ColumnSettings from '../components/column_settings';
import { changeSetting } from 'flavours/glitch/actions/settings';
=======

import { changeColumnParams } from '../../../actions/columns';
import { changeSetting } from '../../../actions/settings';
import ColumnSettings from '../components/column_settings';
>>>>>>> upstream

const mapStateToProps = (state, { columnId }) => {
  const uuid = columnId;
  const columns = state.getIn(['settings', 'columns']);
  const index = columns.findIndex(c => c.get('uuid') === uuid);

  return {
    settings: (uuid && index >= 0) ? columns.get(index).get('params') : state.getIn(['settings', 'community']),
  };
};

const mapDispatchToProps = (dispatch, { columnId }) => {
  return {
    onChange (key, checked) {
      if (columnId) {
        dispatch(changeColumnParams(columnId, key, checked));
      } else {
        dispatch(changeSetting(['community', ...key], checked));
      }
    },
  };
};

export default connect(mapStateToProps, mapDispatchToProps)(ColumnSettings);
