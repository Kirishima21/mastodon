import { useEffect, useCallback, useState } from 'react';

import { useIntl, defineMessages } from 'react-intl';

import { Helmet } from 'react-helmet';
import { Link } from 'react-router-dom';

import type { Map as ImmutableMap, List as ImmutableList } from 'immutable';

import elephantUIPlane from '@/images/elephant_ui_plane.svg';
import EditIcon from '@/material-icons/400-24px/edit_square.svg?react';
import PeopleIcon from '@/material-icons/400-24px/group.svg?react';
import HomeIcon from '@/material-icons/400-24px/home-fill.svg?react';
import LogoutIcon from '@/material-icons/400-24px/logout.svg?react';
import ManufacturingIcon from '@/material-icons/400-24px/manufacturing-fill.svg?react';
import MenuIcon from '@/material-icons/400-24px/menu.svg?react';
import NotificationsIcon from '@/material-icons/400-24px/notifications-fill.svg?react';
import PublicIcon from '@/material-icons/400-24px/public.svg?react';
import { mountCompose, unmountCompose } from 'flavours/glitch/actions/compose';
import { openModal } from 'flavours/glitch/actions/modal';
import { Column } from 'flavours/glitch/components/column';
import { ColumnHeader } from 'flavours/glitch/components/column_header';
import { Icon } from 'flavours/glitch/components/icon';
import glitchedElephant1 from 'flavours/glitch/images/mbstobon-ui-0.png';
import glitchedElephant2 from 'flavours/glitch/images/mbstobon-ui-1.png';
import glitchedElephant3 from 'flavours/glitch/images/mbstobon-ui-2.png';
import { mascot } from 'flavours/glitch/initial_state';
import { useAppDispatch, useAppSelector } from 'flavours/glitch/store';

import { Search } from './components/search';
import ComposeFormContainer from './containers/compose_form_container';

const messages = defineMessages({
  start: { id: 'getting_started.heading', defaultMessage: 'Getting started' },
  home_timeline: { id: 'tabs_bar.home', defaultMessage: 'Home' },
  notifications: {
    id: 'tabs_bar.notifications',
    defaultMessage: 'Notifications',
  },
  public: {
    id: 'navigation_bar.public_timeline',
    defaultMessage: 'Federated timeline',
  },
  community: {
    id: 'navigation_bar.community_timeline',
    defaultMessage: 'Local timeline',
  },
  settings: {
    id: 'navigation_bar.app_settings',
    defaultMessage: 'App settings',
  },
  logout: { id: 'navigation_bar.logout', defaultMessage: 'Logout' },
  compose: { id: 'navigation_bar.compose', defaultMessage: 'Compose new post' },
});

type ColumnMap = ImmutableMap<'id' | 'uuid' | 'params', string>;

// ~4% chance you'll end up with an unexpected friend
// glitch-soc/mastodon repo created_at date: 2017-04-20T21:55:28Z
const glitchProbability = 1 - 0.0420215528;
const totalElefriends = 3;

const Compose: React.FC<{ multiColumn: boolean }> = ({ multiColumn }) => {
  const intl = useIntl();
  const dispatch = useAppDispatch();
  const columns = useAppSelector(
    (state) =>
      (state.settings as ImmutableMap<string, unknown>).get(
        'columns',
      ) as ImmutableList<ColumnMap>,
  );
  const unreadNotifications = useAppSelector(
    (state) => state.notifications.get('unread', 0) as number,
  );
  const showNotificationsBadge = useAppSelector(
    (state) =>
      // eslint-disable-next-line @typescript-eslint/no-unsafe-member-access, @typescript-eslint/no-unsafe-call
      state.local_settings.getIn(
        ['notifications', 'tab_badge'],
        false,
      ) as boolean,
  );
  const [elefriend, setElefriend] = useState(
    Math.random() < glitchProbability
      ? Math.floor(Math.random() * totalElefriends)
      : totalElefriends,
  );

  useEffect(() => {
    dispatch(mountCompose());

    return () => {
      dispatch(unmountCompose());
    };
  }, [dispatch]);

  const handleLogoutClick = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();

      dispatch(openModal({ modalType: 'CONFIRM_LOG_OUT', modalProps: {} }));

      return false;
    },
    [dispatch],
  );

  const handleSettingsClick = useCallback(
    (e: React.MouseEvent) => {
      e.preventDefault();
      e.stopPropagation();

      dispatch(openModal({ modalType: 'SETTINGS', modalProps: {} }));
    },
    [dispatch],
  );

  const handleCycleElefriend = useCallback(() => {
    setElefriend((elefriend + 1) % totalElefriends);
  }, [elefriend, setElefriend]);

  const elephant = [
    glitchedElephant1,
    glitchedElephant2,
    glitchedElephant3,
    elephantUIPlane,
  ][elefriend];

  if (multiColumn) {
    return (
      <div
        className='drawer'
        role='region'
        aria-label={intl.formatMessage(messages.compose)}
      >
        <nav className='drawer__header'>
          <Link
            to='/getting-started'
            className='drawer__tab'
            title={intl.formatMessage(messages.start)}
            aria-label={intl.formatMessage(messages.start)}
          >
            <Icon id='bars' icon={MenuIcon} />
          </Link>
          {!columns.some((column) => column.get('id') === 'HOME') && (
            <Link
              to='/home'
              className='drawer__tab'
              title={intl.formatMessage(messages.home_timeline)}
              aria-label={intl.formatMessage(messages.home_timeline)}
            >
              <Icon id='home' icon={HomeIcon} />
            </Link>
          )}
          {!columns.some((column) => column.get('id') === 'NOTIFICATIONS') && (
            <Link
              to='/notifications'
              className='drawer__tab'
              title={intl.formatMessage(messages.notifications)}
              aria-label={intl.formatMessage(messages.notifications)}
            >
              <span className='icon-badge-wrapper'>
                <Icon id='bell' icon={NotificationsIcon} />
                {showNotificationsBadge && unreadNotifications && (
                  <div className='icon-badge' />
                )}
              </span>
            </Link>
          )}
          {!columns.some((column) => column.get('id') === 'COMMUNITY') && (
            <Link
              to='/public/local'
              className='drawer__tab'
              title={intl.formatMessage(messages.community)}
              aria-label={intl.formatMessage(messages.community)}
            >
              <Icon id='users' icon={PeopleIcon} />
            </Link>
          )}
          {!columns.some((column) => column.get('id') === 'PUBLIC') && (
            <Link
              to='/public'
              className='drawer__tab'
              title={intl.formatMessage(messages.public)}
              aria-label={intl.formatMessage(messages.public)}
            >
              <Icon id='globe' icon={PublicIcon} />
            </Link>
          )}
          <a
            onClick={handleSettingsClick}
            href='/settings/preferences'
            className='drawer__tab'
            title={intl.formatMessage(messages.settings)}
            aria-label={intl.formatMessage(messages.settings)}
          >
            <Icon id='cogs' icon={ManufacturingIcon} />
          </a>
          <a
            href='/auth/sign_out'
            className='drawer__tab'
            title={intl.formatMessage(messages.logout)}
            aria-label={intl.formatMessage(messages.logout)}
            onClick={handleLogoutClick}
          >
            <Icon id='sign-out' icon={LogoutIcon} />
          </a>
        </nav>

        <Search singleColumn={false} />

        <div className='drawer__pager'>
          <div className='drawer__inner'>
            <ComposeFormContainer />

            {/* eslint-disable-next-line jsx-a11y/no-static-element-interactions, jsx-a11y/click-events-have-key-events -- this is not a feature but a visual easter egg */}
            <div
              className='drawer__inner__mastodon'
              onClick={handleCycleElefriend}
            >
              <img alt='' draggable='false' src={mascot ?? elephant} />
            </div>
          </div>
        </div>
      </div>
    );
  }

  return (
    <Column
      bindToDocument={!multiColumn}
      label={intl.formatMessage(messages.compose)}
    >
      <ColumnHeader
        icon='pencil'
        iconComponent={EditIcon}
        title={intl.formatMessage(messages.compose)}
        multiColumn={multiColumn}
        showBackButton
      />

      <div className='scrollable'>
        <ComposeFormContainer />
      </div>

      <Helmet>
        <meta name='robots' content='noindex' />
      </Helmet>
    </Column>
  );
};

// eslint-disable-next-line import/no-default-export
export default Compose;
