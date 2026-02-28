visibility(["//..."])

def ordered_range_constraint_values(
        *,
        constraint_setting,
        values,
        **kwargs):
    """
    Defines an ordered range of values for a given constraint setting with helpers for "at least" and "at most" matches.

    Args:
        constraint_setting: The label of the constraint setting these values belong to.
        values: A list of strings representing the constraint values. These should be ordered from least to greatest.
        **kwargs: Additional keyword arguments to pass to the generated rules (e.g., visibility).
    """
    if not values:
        fail("At least one value must be provided")

    for value in values:
        native.constraint_value(
            name = value,
            constraint_setting = constraint_setting,
            **kwargs
        )

    for i, value in enumerate(values):
        if i < len(values) - 1:
            native.alias(
                name = "at_least_" + value,
                actual = select({
                    ":" + value: ":" + value,
                    "//conditions:default": ":at_least_" + values[i + 1],
                }),
                **kwargs
            )
        else:
            native.config_setting(
                name = "at_least_" + value,
                constraint_values = [
                    ":" + value,
                ],
                **kwargs
            )
        if i > 0:
            native.alias(
                name = "at_most_" + value,
                actual = select({
                    ":" + value: ":" + value,
                    "//conditions:default": ":at_most_" + values[i - 1],
                }),
                **kwargs
            )
        else:
            native.config_setting(
                name = "at_most_" + value,
                constraint_values = [
                    ":" + value,
                ],
                **kwargs
            )
