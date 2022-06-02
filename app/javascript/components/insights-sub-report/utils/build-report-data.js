import { Map } from "immutable";

import { COMBINED_INDICATORS, MEDATADA_INDICATORS } from "../constants";

export default (insight, subReport) => {
  if (!insight.size) {
    return insight;
  }

  const insightOrder = insight.getIn(["report_data", subReport, "order"], Map({}));

  const insightData = insight
    .getIn(["report_data", subReport], Map({}))
    .filterNot((_value, key) => MEDATADA_INDICATORS.includes(key));

  const sortedData = insightOrder.reduce((acc, order) => {
    return acc.set(order, insightData.get(order));
  }, Map({}));

  return sortedData.groupBy((_value, key) =>
    (COMBINED_INDICATORS[subReport] || []).includes(key) ? "single" : "aggregate"
  );
};
