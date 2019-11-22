import React, { useState } from "react";
import PropTypes from "prop-types";
import { connect, useSelector } from "react-redux";
import { makeStyles } from "@material-ui/styles";
import {
  ExpansionPanelDetails,
  ExpansionPanelSummary,
  IconButton
} from "@material-ui/core";
import ExpandMoreIcon from "@material-ui/icons/ExpandMore";

import { RefreshIcon } from "../../images/primero-icons";
import SavedSearchesForm from "../saved-searches/SavedSearchesForm";
import { useI18n } from "../i18n";
import { getFilters } from "../index-table";

import {
  CheckBox,
  SelectFilter,
  RangeButton,
  RadioButton,
  Chips,
  DatesRange,
  SwitchButton
} from "./filter-controls";
import * as actions from "./action-creators";
import { NAME } from "./config";
import { getFiltersByRecordType } from "./selectors";
import Panel from "./Panel";
import styles from "./styles.css";
import { VARIANT_BUTTON_TYPES, COLOR_PRIMARY } from "./constants";
import FiltersActions from "./filters-actions";

const Container = ({
  recordType,
  filters,
  resetPanel,
  resetCurrentPanel,
  recordFilters,
  applyFilters,
  defaultFilters
}) => {
  const css = makeStyles(styles)();
  const i18n = useI18n();
  const [open, setOpen] = useState(false);

  const handleClearFilters = () => {
    resetPanel(recordType, `/${recordType.toLowerCase()}`);
  };

  const handleApplyFilter = () => {
    applyFilters({
      namespace: recordType,
      options: recordFilters,
      path: `/${recordType.toLowerCase()}`
    });
  };

  const handleSaveFilters = () => {
    setOpen(true);
  };

  const renderFilterControl = filter => {
    switch (filter.type) {
      case "checkbox":
        return <CheckBox recordType={recordType} props={filter} />;
      case "multi_select":
        return <SelectFilter recordType={recordType} props={filter} multiple />;
      case "select":
        return <SelectFilter recordType={recordType} props={filter} />;
      case "multi_toggle":
        return <RangeButton recordType={recordType} props={filter} />;
      case "radio":
        return <RadioButton recordType={recordType} props={filter} />;
      case "chips":
        return <Chips recordType={recordType} props={filter} />;
      case "dates":
        return <DatesRange recordType={recordType} props={filter} />;
      case "toggle":
        return <SwitchButton recordType={recordType} props={filter} />;
      default:
        return <h2>Not Found</h2>;
    }
  };

  const handleReset = (field, type) => event => {
    event.stopPropagation();
    resetCurrentPanel({ field_name: field, type }, recordType);
  };

  const savedSearchesFormProps = {
    recordType,
    open,
    setOpen
  };

  const allowedResetFilterTypes = ["radio", "multi_toggle", "chips"];

  const savedFilters = useSelector(state =>
    getFiltersByRecordType(state, recordType)
  );

  const filterValues = filter => {
    const { field_name: fieldName } = filter;
    // TODO: should savedFilters be an immutable?
    return (
      defaultFilters.get(fieldName)?.size > 0 ||
      savedFilters[fieldName]?.length > 0
    );
  };

  const icon = filter => {
    return allowedResetFilterTypes.includes(filter.type) ? (
      <IconButton
        aria-label={i18n.t("buttons.delete")}
        justifycontent="flex-end"
        size="small"
        onClick={handleReset(`${filter.field_name}`, `${filter.type}`)}
      >
        <RefreshIcon />
      </IconButton>
    ) : null;
  };

  const filtersActions = [
    {
      id: "applyFilter",
      label: i18n.t("filters.apply_filters"),
      buttonProps: {
        onClick: handleApplyFilter,
        variant: VARIANT_BUTTON_TYPES.contained,
        color: COLOR_PRIMARY
      }
    },
    {
      id: "saveFilter",
      label: i18n.t("filters.save_filters"),
      buttonProps: {
        onClick: handleSaveFilters,
        variant: VARIANT_BUTTON_TYPES.outlined
      }
    },
    {
      id: "clearFilter",
      label: i18n.t("filters.clear_filters"),
      buttonProps: {
        onClick: handleClearFilters,
        variant: VARIANT_BUTTON_TYPES.outlined
      }
    }
  ];

  return (
    <div className={css.root}>
      <FiltersActions actions={filtersActions} />
      {filters &&
        filters.toJS().map(filter => (
          <Panel
            key={`${recordType}-${filter.field_name}`}
            name={`${recordType}-${filter.field_name}`}
            hasValues={filterValues(filter)}
          >
            <ExpansionPanelSummary
              expandIcon={<ExpandMoreIcon />}
              aria-controls="filter-controls-content"
              id={filter.field_name}
            >
              <div className={css.heading}>
                <span> {i18n.t(`${filter.name}`)} </span>
                {icon(filter)}
              </div>
            </ExpansionPanelSummary>
            <ExpansionPanelDetails className={css.panelDetails}>
              {renderFilterControl(filter)}
            </ExpansionPanelDetails>
          </Panel>
        ))}
      <SavedSearchesForm {...savedSearchesFormProps} />
    </div>
  );
};

Container.propTypes = {
  applyFilters: PropTypes.func,
  defaultFilters: PropTypes.object,
  filters: PropTypes.oneOfType([PropTypes.array, PropTypes.object]),
  recordFilters: PropTypes.object,
  recordType: PropTypes.string.isRequired,
  resetCurrentPanel: PropTypes.func,
  resetPanel: PropTypes.func
};

Container.displayName = NAME;

const mapStateToProps = (state, props) => ({
  recordFilters: getFilters(state, props.recordType)
});

const mapDispatchToProps = {
  resetCurrentPanel: actions.resetSinglePanel,
  applyFilters: actions.applyFilters
};

export default connect(
  mapStateToProps,
  mapDispatchToProps
)(Container);