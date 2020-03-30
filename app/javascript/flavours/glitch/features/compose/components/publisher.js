/* eslint react/jsx-no-bind: 0 */

//  Package imports.
import classNames from 'classnames';
import PropTypes from 'prop-types';
import React from 'react';
import { defineMessages, FormattedMessage, injectIntl } from 'react-intl';
import { length } from 'stringz';
import ImmutablePureComponent from 'react-immutable-pure-component';

//  Components.
import Button from 'flavours/glitch/components/button';
import Icon from 'flavours/glitch/components/icon';

//  Utils.
import { maxChars } from 'flavours/glitch/util/initial_state';

//  Messages.
const messages = defineMessages({
  publish: {
    defaultMessage: 'Toot',
    id: 'compose_form.publish',
  },
  publishLoud: {
    defaultMessage: '{publish}!',
    id: 'compose_form.publish_loud',
  },
});

export default @injectIntl
class Publisher extends ImmutablePureComponent {

  static propTypes = {
    countText: PropTypes.string,
    disabled: PropTypes.bool,
    intl: PropTypes.object.isRequired,
    onSecondarySubmit: PropTypes.func,
    onSubmit: PropTypes.func,
    privacy: PropTypes.oneOf(['direct', 'private', 'unlisted', 'public']),
    sideArm: PropTypes.oneOf(['none', 'direct', 'private', 'unlisted', 'public']),
    showSideArmLocalToot: PropTypes.bool,
    showSideArmLocalSecondary: PropTypes.bool,
    handleSideArmLocalSubmit: PropTypes.func,
  };

  handleSubmit = () => {
    this.props.onSubmit();
  };

  render () {
    const { countText, disabled, intl, onSecondarySubmit, privacy, sideArm } = this.props;
    const { showSideArmLocalToot, showSideArmLocalSecondary, handleSideArmLocalSubmit } = this.props;

    const diff = maxChars - length(countText || '');
    const computedClass = classNames('composer--publisher', {
      disabled: disabled || diff < 0,
      over: diff < 0,
    });

    return (
      <div className={computedClass}>
        {sideArm && sideArm !== 'none' && showSideArmLocalSecondary && (
          <Button
            className='side_arm is_local'
            disabled={disabled || diff < 0}
            onClick={() => handleSideArmLocalSubmit(sideArm)}
            text={
              <span>
                <Icon
                  id={{
                    public: 'globe',
                    unlisted: 'unlock',
                    private: 'lock',
                    direct: 'envelope',
                  }[sideArm]}
                  fixedWidth
                />
                <Icon id='home' fixedWidth />
              </span>
            }
            title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${sideArm}.short` })} (${intl.formatMessage({ id: 'advanced_options.local-only.short' })})`}
          />
        )}

        {sideArm && sideArm !== 'none' ? (
          <Button
            className='side_arm'
            disabled={disabled || diff < 0}
            onClick={onSecondarySubmit}
            style={{ padding: null }}
            text={
              <span>
                <Icon
                  id={{
                    public: 'globe',
                    unlisted: 'unlock',
                    private: 'lock',
                    direct: 'envelope',
                  }[sideArm]}
                />
              </span>
            }
            title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${sideArm}.short` })}`}
          />
        ) : null}

        {showSideArmLocalToot && (
          <Button
            className='side_arm is_local'
            disabled={disabled || diff < 0}
            onClick={() => handleSideArmLocalSubmit(privacy)}
            text={
              <span>
                <Icon
                  id={{
                    public: 'globe',
                    unlisted: 'unlock',
                    private: 'lock',
                    direct: 'envelope',
                  }[privacy]}
                  fixedWidth
                />
                <Icon id='home' fixedWidth />
              </span>
            }
            title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${privacy}.short` })} (${intl.formatMessage({ id: 'advanced_options.local-only.short' })})`}
          />
        )}

        <Button
          className='primary'
          text={function () {
            switch (true) {
            case !!sideArm && sideArm !== 'none':
            case privacy === 'direct':
            case privacy === 'private':
              return (
                <span>
                  <Icon
                    id={{
                      direct: 'envelope',
                      private: 'lock',
                      public: 'globe',
                      unlisted: 'unlock',
                    }[privacy]}
                  />
                  {' '}
                  <FormattedMessage {...messages.publish} />
                </span>
              );
            case privacy === 'public':
              return (
                <span>
                  <FormattedMessage
                    {...messages.publishLoud}
                    values={{ publish: <FormattedMessage {...messages.publish} /> }}
                  />
                </span>
              );
            default:
              return <span><FormattedMessage {...messages.publish} /></span>;
            }
          }()}
          title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage({ id: `privacy.${privacy}.short` })}`}
          onClick={this.handleSubmit}
          disabled={disabled || diff < 0}
        />
      </div>
    );
  };
}
