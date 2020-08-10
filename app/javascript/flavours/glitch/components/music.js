/* eslint react/jsx-no-bind: 0 */

import React from 'react';
import IconButton from './announcement_icon_button';

const musicList = [
  { name: 'Listen.moe', url: 'https://listen.moe/stream' },
  { name: 'AnimeNfo Radio', url: 'https://itori.animenfo.com:443/;' },
  { name: 'LoFi hip hop Radio', url: 'https://hyades.shoutca.st:8043/stream' },
  { name: 'Linn Classical', url: 'https://89.16.185.174:8004/stream' },
  { name: 'Linn Jazz', url: 'https://89.16.185.174:8000/stream' },
  { name: 'canal-jazz.eu', url: 'https://91.121.59.45:10024/stream' },
  { name: 'Poolside.fm', url: 'https://stream.radio.co/s98f81d47e/listen' },
  { name: 'Drum \'n Bass', sub: 'dubplate.fm', url: 'https://sc2.dubplate.fm:5000/DnB/192' },
  { name: 'FUTURE-BASS-MIX', url: 'https://stream.zenolive.com/am16uk1f4k5tv' },
  {
    name: 'TOP 40 RU',
    sub: 'European Hit Radio',
    url: 'https://stream.europeanhitradio.com:8000/Stream_35.aac',
  },
  {
    name: 'REMIXES RU',
    sub: 'European Hit Radio',
    url: 'https://stream.europeanhitradio.com:8000/Stream_33.aac',
  },
  { name: 'FMHIPHOP.COM', url: 'https://149.56.175.167:5708/;' },
  { name: 'Vapor.fm', url: 'https://vapor.fm:8000/stream' },
];

export default class Music extends React.PureComponent {

  state = {
    audio: new Audio(),
    name: '',
    isPlaying: false,
  };

  musicTogglePlay() {
    const { audio, name, isPlaying } = this.state;

    if (!name) return this.musicChangeSrc(0);

    this.setState({ isPlaying: !isPlaying });
    return isPlaying ? audio.pause() : audio.play();
  }

  musicChangeSrc(index) {
    const { audio } = this.state;

    audio.src = musicList[index].url;
    audio.play();
    this.setState({ name: musicList[index].name, isPlaying: true });
  }

  render () {
    const { name, isPlaying } = this.state;

    return (
      <p>
        <span>{isPlaying ? name : 'Not Playing'}</span>
        <IconButton icon={isPlaying ? 'pause' : 'play'} onClick={() => this.musicTogglePlay()} size={17}  title='Enjoy Kirishima Music!' />
        <br /><br />

        <ul className='musicList'>
          {musicList.map((item, index) => <li onClick={() => this.musicChangeSrc(index)}>{item.name}</li>)}
        </ul>
      </p>
    );
  }

}
