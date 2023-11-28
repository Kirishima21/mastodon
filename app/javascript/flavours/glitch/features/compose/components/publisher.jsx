/* eslint react/jsx-no-bind: 0 */
import PropTypes from 'prop-types';

import { defineMessages, injectIntl } from 'react-intl';

import classNames from 'classnames';

import ImmutablePureComponent from 'react-immutable-pure-component';

import { length } from 'stringz';

import { Button } from 'flavours/glitch/components/button';
import { Icon } from 'flavours/glitch/components/icon';
import { maxChars } from 'flavours/glitch/initial_state';

const messages = defineMessages({
  publish: {
    defaultMessage: 'Publish',
    id: 'compose_form.publish',
  },
  publishLoud: {
    defaultMessage: '{publish}!',
    id: 'compose_form.publish_loud',
  },
  saveChanges: { id: 'compose_form.save_changes', defaultMessage: 'Save changes' },
  public: { id: 'privacy.public.short', defaultMessage: 'Public' },
  unlisted: { id: 'privacy.unlisted.short', defaultMessage: 'Unlisted' },
  private: { id: 'privacy.private.short', defaultMessage: 'Followers only' },
  direct: { id: 'privacy.direct.short', defaultMessage: 'Mentioned people only' },
});

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
    isEditing: PropTypes.bool,
  };

  handleSubmit = () => {
    this.props.onSubmit();
  };

  render () {
    const { countText, disabled, intl, onSecondarySubmit, privacy, sideArm, isEditing } = this.props;
    const { showSideArmLocalToot, showSideArmLocalSecondary, handleSideArmLocalSubmit } = this.props;
    const diff = maxChars - length(countText || '');
    const computedClass = classNames('compose-form__publish', {
      disabled: disabled,
      over: diff < 0,
    });

    const privacyIcons = { direct: 'envelope', private: 'lock', public: 'globe', unlisted: 'unlock' };

    let publishText;
    if (isEditing) {
      publishText = intl.formatMessage(messages.saveChanges);
    } else if (privacy === 'private' || privacy === 'direct') {
      const iconId = privacyIcons[privacy];
      publishText = (
        <span>
          <Icon id={iconId} /> {intl.formatMessage(messages.publish)}
        </span>
      );
    } else {
      publishText = privacy !== 'unlisted' ? intl.formatMessage(messages.publishLoud, { publish: intl.formatMessage(messages.publish) }) : intl.formatMessage(messages.publish);
    }

    const privacyNames = {
      public: messages.public,
      unlisted: messages.unlisted,
      private: messages.private,
      direct: messages.direct,
    };

    const privacyMessages = {
      public: { id: 'privacy.public.short' },
      unlisted: { id: 'privacy.unlisted.short' },
      private: { id: 'privacy.private.short' },
      direct: { id: 'privacy.direct.short' },
      // 他の可能な値をここに追加
    };

    return (
      <div className={computedClass}>
        {sideArm && sideArm !== 'none' && showSideArmLocalSecondary && (
          <div className='compose-form__publish-button-wrapper'>
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
              title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage(privacyMessages[sideArm])} (${intl.formatMessage({ id: 'advanced_options.local-only.short' })})`}
            />
          </div>
        )}
        {sideArm && !isEditing && sideArm !== 'none' ? (
          <div className='compose-form__publish-button-wrapper'>
            <Button
              className='side_arm'
              disabled={disabled}
              onClick={onSecondarySubmit}
              style={{ padding: null }}
              text={<Icon id={privacyIcons[sideArm]} />}
              title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage(privacyNames[sideArm])}`}
            />
          </div>
        ) : null}
        {showSideArmLocalToot && (
          <div className='compose-form__publish-button-wrapper'>
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
              title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage(privacyMessages[sideArm])} (${intl.formatMessage({ id: 'advanced_options.local-only.short' })})`}
            />
          </div>
        )}
        <div className='compose-form__publish-button-wrapper'>
          <Button
            className='primary'
            text={publishText}
            title={`${intl.formatMessage(messages.publish)}: ${intl.formatMessage(privacyNames[privacy])}`}
            onClick={this.handleSubmit}
            disabled={disabled}
          />
        </div>
      </div>
    );
  }

}

export default injectIntl(Publisher);
