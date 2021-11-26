import { isBefore, parseISO } from "date-fns";
import isEqualDate from "date-fns/isEqual";
import first from "lodash/first";

import { isApiDate } from "../../component-helpers";
import { COMPARISON_OPERATORS } from "../constants";

export default expression => ({
  expression,
  operator: COMPARISON_OPERATORS.LE,
  evaluate: data => {
    const [key, value] = first(Object.entries(expression));

    if (Array.isArray(value)) {
      throw Error(`Invalid argument ${value} for ${COMPARISON_OPERATORS.LE} operator`);
    }

    if (isApiDate(value)) {
      const date1 = parseISO(data[key]);
      const date2 = parseISO(value);

      return isBefore(date1, date2) || isEqualDate(date1, date2);
    }

    return data[key] <= value;
  }
});
